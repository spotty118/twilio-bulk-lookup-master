class DuplicateDetectionService
  # Find all duplicates for a contact
  def self.find_duplicates(contact)
    new(contact).find_duplicates
  end

  # Merge two contacts
  def self.merge(primary_contact, duplicate_contact)
    new(primary_contact).merge_with(duplicate_contact)
  end

  def initialize(contact)
    @contact = contact
  end

  def find_duplicates
    return [] if @contact.is_duplicate?

    candidates = []

    # Phone number exact match
    candidates += find_by_phone_exact if @contact.formatted_phone_number.present?

    # Phone number fuzzy match
    candidates += find_by_phone_fuzzy if @contact.raw_phone_number.present?

    # Email exact match
    candidates += find_by_email if @contact.email.present?

    # Business name + location match
    candidates += find_by_business_identity if @contact.business?

    # Name match (for consumer contacts)
    candidates += find_by_name if @contact.full_name.present?

    # Score and rank candidates
    scored_candidates = candidates.uniq.map do |candidate|
      match_reason = determine_match_reason(@contact, candidate)
      {
        contact: candidate,
        confidence: calculate_match_confidence(@contact, candidate),
        reason: match_reason
      }
    end

    # Filter by confidence threshold
    threshold = TwilioCredential.current&.duplicate_confidence_threshold || 80
    scored_candidates.select { |c| c[:confidence] >= threshold }
                     .sort_by { |c| -c[:confidence] }
  end

  def merge_with(duplicate_contact)
    return false if @contact.id == duplicate_contact.id

    ActiveRecord::Base.transaction do
      # Lock both contacts to prevent concurrent modifications
      ids = [@contact.id, duplicate_contact.id].sort
      locked = Contact.lock.where(id: ids).order(:id).index_by(&:id)
      primary = locked[@contact.id]
      duplicate = locked[duplicate_contact.id]

      return false unless primary && duplicate

      # Double-check neither is already a duplicate after acquiring lock
      return false if primary.is_duplicate? || duplicate.is_duplicate?

      # Merge all data, preferring primary contact's data
      merged_data = merge_data(primary, duplicate)
      merged_data[:duplicate_checked_at] = Time.current

      # Update primary contact with merged data
      primary.update!(merged_data)

      # Record merge history
      merge_record = {
        merged_at: Time.current,
        duplicate_id: duplicate.id,
        duplicate_data: duplicate.attributes.except('id', 'created_at', 'updated_at')
      }

      # Reassign array to ensure Rails detects the change
      merge_history = primary.merge_history || []
      merge_history << merge_record
      primary.merge_history = merge_history
      primary.save!

      # Mark duplicate as merged
      duplicate.update!(
        is_duplicate: true,
        duplicate_of_id: primary.id,
        duplicate_confidence: 100,
        duplicate_checked_at: Time.current
      )

      # Update fingerprints and quality scores
      primary.update_fingerprints!
      primary.calculate_quality_score!

      # Update instance variable to reflect changes
      @contact.reload

      true
    end
  rescue StandardError => e
    Rails.logger.error(
      "Merge failed for contacts (primary: #{primary.id}, duplicate: #{duplicate.id}): " \
      "#{e.class} - #{e.message}"
    )
    Rails.logger.error(e.backtrace.first(5).join("\n"))
    false
  end

  private

  def find_by_phone_exact
    return [] unless @contact.formatted_phone_number.present?

    Contact.where(formatted_phone_number: @contact.formatted_phone_number)
           .where.not(id: @contact.id)
           .where(is_duplicate: false)
           .to_a
  end

  def find_by_phone_fuzzy
    return [] unless @contact.phone_fingerprint.present?

    Contact.where(phone_fingerprint: @contact.phone_fingerprint)
           .where.not(id: @contact.id)
           .where(is_duplicate: false)
           .to_a
  end

  def find_by_email
    return [] unless @contact.email.present?

    if @contact.email_fingerprint.present?
      Contact.where(email_fingerprint: @contact.email_fingerprint)
             .where.not(id: @contact.id)
             .where(is_duplicate: false)
             .to_a
    else
      Contact.where(email: @contact.email)
             .where.not(id: @contact.id)
             .where(is_duplicate: false)
             .to_a
    end
  end

  def find_by_business_identity
    return [] unless @contact.business_name.present?

    # Match on business name + location
    contacts = Contact.where(is_business: true)
                     .where.not(id: @contact.id)
                     .where(is_duplicate: false)

    if @contact.name_fingerprint.present?
      contacts = contacts.where(name_fingerprint: @contact.name_fingerprint)
    else
      contacts = contacts.where(business_name: @contact.business_name)
    end

    # Further filter by location if available
    if @contact.business_city.present?
      contacts = contacts.where(business_city: @contact.business_city)
    end

    contacts.to_a
  end

  def find_by_name
    return [] unless @contact.name_fingerprint.present?

    Contact.where(name_fingerprint: @contact.name_fingerprint)
           .where.not(id: @contact.id)
           .where(is_duplicate: false)
           .to_a
  end

  def calculate_match_confidence(contact1, contact2)
    # Skip empty contacts - no meaningful data to compare
    return 0 if contact1.formatted_phone_number.blank? && contact1.email.blank? && contact1.full_name.blank? && contact1.business_name.blank?
    return 0 if contact2.formatted_phone_number.blank? && contact2.email.blank? && contact2.full_name.blank? && contact2.business_name.blank?

    score = 0
    max_score = 0

    # Phone number match (highest weight)
    max_score += 40
    if contact1.formatted_phone_number.present? && contact2.formatted_phone_number.present?
      if contact1.formatted_phone_number == contact2.formatted_phone_number
        score += 40
      elsif phone_similarity(contact1.raw_phone_number, contact2.raw_phone_number) > 0.8
        score += 30
      end
    end

    # Email match
    max_score += 30
    if contact1.email.present? && contact2.email.present?
      if contact1.email.downcase == contact2.email.downcase
        score += 30
      elsif email_domain_match?(contact1.email, contact2.email)
        score += 15
      end
    end

    # Name match (for businesses or people)
    max_score += 20
    if contact1.business?
      if contact1.business_name.present? && contact2.business_name.present?
        similarity = string_similarity(contact1.business_name, contact2.business_name)
        score += (similarity * 20).to_i
      end
    else
      if contact1.full_name.present? && contact2.full_name.present?
        similarity = string_similarity(contact1.full_name, contact2.full_name)
        score += (similarity * 20).to_i
      end
    end

    # Location match (for businesses)
    max_score += 10
    if contact1.business_city.present? && contact2.business_city.present?
      if contact1.business_city.downcase == contact2.business_city.downcase
        score += 10
      end
    end

    # Return percentage confidence
    max_score > 0 ? ((score.to_f / max_score) * 100).round : 0
  end

  def phone_similarity(phone1, phone2)
    return 0 unless phone1.present? && phone2.present?

    # Remove all non-digits
    p1 = phone1.gsub(/\D/, '')
    p2 = phone2.gsub(/\D/, '')

    # Check last 10 digits (for international numbers)
    p1_last10 = p1.length > 10 ? p1[-10..-1] : p1
    p2_last10 = p2.length > 10 ? p2[-10..-1] : p2

    return 1.0 if p1_last10 == p2_last10

    # Levenshtein distance
    distance = levenshtein_distance(p1_last10, p2_last10)
    max_length = [p1_last10.length, p2_last10.length].max
    return 0 if max_length == 0

    1.0 - (distance.to_f / max_length)
  end

  def email_domain_match?(email1, email2)
    return false unless email1.include?('@') && email2.include?('@')

    domain1 = email1.split('@').last
    domain2 = email2.split('@').last
    domain1.downcase == domain2.downcase
  end

  def determine_match_reason(contact1, contact2)
    reasons = []

    # Check phone match
    if contact1.formatted_phone_number.present? && contact2.formatted_phone_number.present?
      if contact1.formatted_phone_number == contact2.formatted_phone_number
        reasons << "Exact phone match"
      elsif phone_similarity(contact1.raw_phone_number, contact2.raw_phone_number) > 0.8
        reasons << "Similar phone number"
      end
    end

    # Check email match
    if contact1.email.present? && contact2.email.present?
      if contact1.email.downcase == contact2.email.downcase
        reasons << "Exact email match"
      elsif email_domain_match?(contact1.email, contact2.email)
        reasons << "Same email domain"
      end
    end

    # Check business name match
    if contact1.business? && contact1.business_name.present? && contact2.business_name.present?
      similarity = string_similarity(contact1.business_name, contact2.business_name)
      reasons << "Similar business name (#{(similarity * 100).round}%)" if similarity > 0.7
    end

    # Check person name match
    if !contact1.business? && contact1.full_name.present? && contact2.full_name.present?
      similarity = string_similarity(contact1.full_name, contact2.full_name)
      reasons << "Similar name (#{(similarity * 100).round}%)" if similarity > 0.7
    end

    # Check location match
    if contact1.business_city.present? && contact2.business_city.present?
      if contact1.business_city.downcase == contact2.business_city.downcase
        reasons << "Same city"
      end
    end

    reasons.any? ? reasons.join(", ") : "Multiple field similarities"
  end

  def string_similarity(str1, str2)
    return 0 unless str1.present? && str2.present?

    s1 = str1.downcase.strip
    s2 = str2.downcase.strip

    return 1.0 if s1 == s2

    # Levenshtein distance
    distance = levenshtein_distance(s1, s2)
    max_length = [s1.length, s2.length].max
    return 0 if max_length == 0

    1.0 - (distance.to_f / max_length)
  end

  # Levenshtein distance algorithm
  def levenshtein_distance(s1, s2)
    return s2.length if s1.empty?
    return s1.length if s2.empty?

    matrix = Array.new(s1.length + 1) { Array.new(s2.length + 1) }

    (0..s1.length).each { |i| matrix[i][0] = i }
    (0..s2.length).each { |j| matrix[0][j] = j }

    (1..s1.length).each do |i|
      (1..s2.length).each do |j|
        cost = s1[i - 1] == s2[j - 1] ? 0 : 1
        matrix[i][j] = [
          matrix[i - 1][j] + 1,      # deletion
          matrix[i][j - 1] + 1,      # insertion
          matrix[i - 1][j - 1] + cost # substitution
        ].min
      end
    end

    matrix[s1.length][s2.length]
  end

  def merge_data(primary, duplicate)
    merged = {}

    # For each field, prefer non-nil value from primary, then duplicate
    # Or if both present, prefer higher quality data

    # Phone data
    merged[:formatted_phone_number] = best_value(
      primary.formatted_phone_number,
      duplicate.formatted_phone_number
    )

    # Email data
    if primary.email_verified || !duplicate.email_verified
      merged[:email] = primary.email || duplicate.email
      merged[:email_verified] = primary.email_verified || duplicate.email_verified
      merged[:email_score] = [primary.email_score, duplicate.email_score].compact.max
    else
      merged[:email] = duplicate.email
      merged[:email_verified] = duplicate.email_verified
      merged[:email_score] = duplicate.email_score
    end

    # Name data
    merged[:full_name] = best_value(primary.full_name, duplicate.full_name)
    merged[:first_name] = best_value(primary.first_name, duplicate.first_name)
    merged[:last_name] = best_value(primary.last_name, duplicate.last_name)

    # Business data - prefer enriched data
    if primary.business_enriched? || !duplicate.business_enriched?
      merged[:business_name] = best_value(primary.business_name, duplicate.business_name)
      merged[:business_employee_count] = best_value(primary.business_employee_count, duplicate.business_employee_count)
      merged[:business_annual_revenue] = best_value(primary.business_annual_revenue, duplicate.business_annual_revenue)
      merged[:business_website] = best_value(primary.business_website, duplicate.business_website)
    else
      merged[:business_name] = duplicate.business_name || primary.business_name
      merged[:business_employee_count] = duplicate.business_employee_count || primary.business_employee_count
      merged[:business_annual_revenue] = duplicate.business_annual_revenue || primary.business_annual_revenue
      merged[:business_website] = duplicate.business_website || primary.business_website
    end

    # Collect additional emails
    emails = [primary.email, duplicate.email, *primary.additional_emails, *duplicate.additional_emails].compact.uniq
    merged[:additional_emails] = emails.reject { |e| e == merged[:email] }

    merged
  end

  def best_value(primary_value, duplicate_value)
    return primary_value if primary_value.present?
    duplicate_value
  end
end
