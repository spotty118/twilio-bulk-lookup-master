ActiveAdmin.register_page 'Duplicates' do
  menu priority: 3, label: 'Duplicate Manager'

  content do
    # Statistics
    total_duplicates = Contact.confirmed_duplicates.count
    potential_duplicates = Contact.potential_duplicates.count

    panel '📊 Duplicate Statistics' do
      div style: 'display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; margin-bottom: 20px;' do
        div class: 'stat-card', style: 'border-left: 4px solid #dc3545;' do
          div class: 'stat-number', style: 'color: #dc3545;' do
            total_duplicates.to_s
          end
          div class: 'stat-label' do
            'Confirmed Duplicates'
          end
        end

        div class: 'stat-card', style: 'border-left: 4px solid #f39c12;' do
          div class: 'stat-number', style: 'color: #f39c12;' do
            potential_duplicates.to_s
          end
          div class: 'stat-label' do
            'Need Review'
          end
        end

        div class: 'stat-card', style: 'border-left: 4px solid #11998e;' do
          div class: 'stat-number', style: 'color: #11998e;' do
            Contact.primary_contacts.count.to_s
          end
          div class: 'stat-label' do
            'Unique Contacts'
          end
        end
      end
    end

    # Potential Duplicates needing review
    panel '⚠️ Potential Duplicates (High Confidence)' do
      # Find contacts with potential duplicates
      contacts_with_dupes = []

      Contact.primary_contacts
             .where('duplicate_checked_at IS NULL OR duplicate_checked_at < ?', 7.days.ago)
             .limit(50)
             .each do |contact|
        dupes = DuplicateDetectionService.find_duplicates(contact)
        contacts_with_dupes << { contact: contact, duplicates: dupes } if dupes.any? { |d| d[:confidence] >= 80 }
      end

      if contacts_with_dupes.any?
        contacts_with_dupes.each do |item|
          contact = item[:contact]
          duplicates = item[:duplicates]

          div style: 'background: #fff3cd; padding: 20px; border-radius: 8px; margin-bottom: 20px; border-left: 4px solid #f39c12;' do
            # Primary contact
            div style: 'margin-bottom: 15px;' do
              h3 style: 'margin: 0 0 10px 0;' do
                'Primary: '
                link_to contact.business_display_name, admin_contact_path(contact), style: 'color: #2c3e50;'
              end

              div style: 'display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 10px; font-size: 14px; color: #6c757d;' do
                div { "Phone: #{contact.formatted_phone_number}" }
                div { "Email: #{contact.email || 'N/A'}" } if contact.email.present?
                div { "Quality: #{contact.data_quality_score || 'N/A'}/100" }
                div { "ID: #{contact.id}" }
              end
            end

            # Potential duplicates
            div do
              strong 'Potential Duplicates:', style: 'display: block; margin-bottom: 10px;'

              duplicates.first(3).each do |dup_data|
                dup = dup_data[:contact]
                confidence = dup_data[:confidence]

                div style: 'background: white; padding: 15px; margin-bottom: 10px; border-radius: 4px; border: 1px solid #dee2e6;' do
                  div style: 'display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px;' do
                    div do
                      link_to dup.business_display_name, admin_contact_path(dup),
                              style: 'font-weight: bold; color: #667eea;'
                    end
                    div do
                      status_tag "#{confidence}% Match", class: confidence >= 90 ? 'error' : 'warning'
                    end
                  end

                  div style: 'display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 10px; font-size: 13px; color: #6c757d;' do
                    div { "Phone: #{dup.formatted_phone_number}" }
                    div { "Email: #{dup.email || 'N/A'}" } if dup.email.present?
                    div { "Quality: #{dup.data_quality_score || 'N/A'}/100" }
                    div { "ID: #{dup.id}" }
                  end

                  div style: 'margin-top: 10px; display: flex; gap: 10px;' do
                    form action: merge_admin_duplicates_path, method: :post, style: 'display: inline;' do |f|
                      input type: 'hidden', name: 'authenticity_token', value: form_authenticity_token
                      input type: 'hidden', name: 'primary_id', value: contact.id
                      input type: 'hidden', name: 'duplicate_id', value: dup.id
                      input type: 'submit', value: 'Merge into Primary', class: 'button primary',
                            onclick: "return confirm('Merge #{dup.business_display_name} into #{contact.business_display_name}? This cannot be undone.')"
                    end

                    form action: mark_not_duplicate_admin_duplicates_path, method: :post,
                         style: 'display: inline;' do |f|
                      input type: 'hidden', name: 'authenticity_token', value: form_authenticity_token
                      input type: 'hidden', name: 'contact_id', value: contact.id
                      input type: 'hidden', name: 'not_duplicate_id', value: dup.id
                      input type: 'submit', value: 'Not a Duplicate', class: 'button'
                    end
                  end
                end
              end
            end
          end
        end
      else
        para '✅ No potential duplicates found. All contacts appear unique!',
             style: 'text-align: center; padding: 40px; color: #11998e; font-size: 16px;'
      end
    end

    # Confirmed duplicates (already merged)
    panel '📝 Merge History (Last 50)' do
      merged_contacts = Contact.confirmed_duplicates
                               .order(updated_at: :desc)
                               .limit(50)

      if merged_contacts.any?
        # OPTIMIZATION: Batch load all primary contacts to avoid N+1 queries
        # This replaces 50 individual Contact.find_by calls with 1 query
        primary_ids = merged_contacts.map(&:duplicate_of_id).compact.uniq
        primary_contacts_map = Contact.where(id: primary_ids).index_by(&:id)

        table_for merged_contacts do
          column('Duplicate Contact') { |c| c.business_display_name }
          column('Phone') { |c| c.formatted_phone_number }
          column('Merged Into') do |c|
            if c.duplicate_of_id
              primary = primary_contacts_map[c.duplicate_of_id]
              if primary
                link_to primary.business_display_name, admin_contact_path(primary)
              else
                'Contact deleted'
              end
            else
              'Contact deleted'
            end
          end
          column('Confidence') { |c| c.duplicate_confidence ? "#{c.duplicate_confidence}%" : 'N/A' }
          column('Merged At') { |c| c.updated_at.strftime('%b %d, %Y %H:%M') }
          column('Actions') do |c|
            link_to 'View', admin_contact_path(c), class: 'button'
          end
        end
      else
        para 'No merge history yet.', style: 'text-align: center; padding: 20px; color: #6c757d;'
      end
    end
  end

  # Merge action
  page_action :merge, method: :post do
    primary = Contact.find_by(id: params[:primary_id])
    duplicate = Contact.find_by(id: params[:duplicate_id])

    unless primary && duplicate
      redirect_to admin_duplicates_path, alert: '❌ One or both contacts not found. They may have been deleted.'
      return
    end

    if DuplicateDetectionService.merge(primary, duplicate)
      redirect_to admin_duplicates_path,
                  notice: "✅ Successfully merged #{duplicate.business_display_name} into #{primary.business_display_name}"
    else
      redirect_to admin_duplicates_path, alert: '❌ Failed to merge contacts. Check logs for details.'
    end
  rescue StandardError => e
    Rails.logger.error("Merge action error: #{e.message}")
    redirect_to admin_duplicates_path, alert: "❌ Error merging contacts: #{e.message}"
  end

  # Mark as not duplicate
  page_action :mark_not_duplicate, method: :post do
    contact = Contact.find_by(id: params[:contact_id])
    not_duplicate = Contact.find_by(id: params[:not_duplicate_id])

    unless contact
      redirect_to admin_duplicates_path, alert: '❌ Contact not found. It may have been deleted.'
      return
    end

    contact.update(duplicate_checked_at: Time.current)
    not_duplicate&.update(duplicate_checked_at: Time.current)
    redirect_to admin_duplicates_path, notice: '✅ Marked as not a duplicate'
  rescue StandardError => e
    Rails.logger.error("Mark not duplicate error: #{e.message}")
    redirect_to admin_duplicates_path, alert: "❌ Error updating contact: #{e.message}"
  end
end
