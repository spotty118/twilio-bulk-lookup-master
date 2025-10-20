class VerizonProbabilityCalculationJob < ApplicationJob
  queue_as :default

  def perform(contact_id)
    contact = Contact.find_by(id: contact_id)

    unless contact
      Rails.logger.error "[VerizonProbabilityJob] Contact ##{contact_id} not found"
      return
    end

    # Check if contact needs probability calculation
    unless should_calculate_probability?(contact)
      Rails.logger.info "[VerizonProbabilityJob] Contact ##{contact_id} doesn't need probability calculation"
      return
    end

    Rails.logger.info "[VerizonProbabilityJob] Calculating probability for contact ##{contact_id}"

    # Initialize probability service
    probability_service = VerizonProbabilityService.new(contact)

    # Calculate probabilities
    probabilities = probability_service.calculate_probabilities

    if probabilities
      # Update contact with results
      contact.verizon_5g_probability = probabilities[:five_g]
      contact.verizon_lte_probability = probabilities[:lte]

      # Merge tower data into coverage data JSON
      contact.verizon_coverage_data ||= {}
      contact.verizon_coverage_data['probability_calculation'] = probabilities[:tower_data]
      contact.verizon_coverage_data['probability_calculated_at'] = Time.current.iso8601

      if contact.save
        Rails.logger.info "[VerizonProbabilityJob] Successfully calculated probability for contact ##{contact_id}"
      else
        Rails.logger.error "[VerizonProbabilityJob] Failed to save probability for contact ##{contact_id}: #{contact.errors.full_messages.join(', ')}"
      end
    else
      Rails.logger.warn "[VerizonProbabilityJob] Failed to calculate probability for contact ##{contact_id}"
    end
  rescue StandardError => e
    Rails.logger.error "[VerizonProbabilityJob] Error calculating probability for contact ##{contact_id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise # Let job retry
  end

  private

  def should_calculate_probability?(contact)
    # Must have coordinates
    return false unless contact.latitude.present? && contact.longitude.present?

    # Must have coverage checked
    return false unless contact.verizon_coverage_checked?

    # If probability already exists and is recent, skip
    if contact.verizon_5g_probability.present? && contact.verizon_lte_probability.present?
      calc_timestamp = contact.verizon_coverage_data&.dig('probability_calculated_at')
      if calc_timestamp
        begin
          calc_time = Time.zone.parse(calc_timestamp)
          return false if calc_time > 7.days.ago
        rescue StandardError
          # Invalid timestamp, proceed with calculation
        end
      end
    end

    true
  end
end
