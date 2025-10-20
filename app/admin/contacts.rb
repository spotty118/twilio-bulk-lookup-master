ActiveAdmin.register Contact do
  active_admin_import validate: true
  
  # ========================================
  # Menu & Configuration
  # ========================================
  menu priority: 2, label: "Phone Numbers"
  
  # ========================================
  # Scopes for Quick Filtering
  # ========================================
  scope :all, default: true
  scope :pending
  scope :processing
  scope :completed
  scope :failed
  scope :not_processed, label: "Need Processing"

  # Fraud risk scopes
  scope :high_risk, label: "🚨 High Risk"
  scope :medium_risk, label: "⚠️ Medium Risk"
  scope :low_risk, label: "✅ Low Risk"
  scope :blocked_numbers, label: "🚫 Blocked"

  # Line type scopes
  scope :mobile, label: "📱 Mobile"
  scope :landline, label: "☎️ Landline"
  scope :voip, label: "💻 VoIP"

  # Business intelligence scopes
  scope :businesses, label: "🏢 Businesses"
  scope :consumers, label: "👤 Consumers"
  scope :business_enriched, label: "✅ Enriched"
  scope :needs_enrichment, label: "⏳ Needs Enrichment"

  # Email scopes
  scope :email_enriched, label: "✉️ Email Enriched"
  scope :with_verified_email, label: "✅ Verified Email"

  # Duplicate detection scopes
  scope :primary_contacts, label: "🎯 Unique Contacts"
  scope :confirmed_duplicates, label: "🔗 Duplicates"
  scope :high_quality, label: "⭐ High Quality"
  
  # ========================================
  # Filters
  # ========================================
  filter :status, as: :select, collection: Contact::STATUSES
  filter :device_type, as: :select, collection: ['mobile', 'landline', 'voip']
  filter :line_type, as: :select, collection: ['mobile', 'landline', 'voip', 'fixedVoip', 'nonFixedVoip', 'tollFree']
  filter :carrier_name
  filter :raw_phone_number
  filter :formatted_phone_number
  filter :country_code, as: :select
  filter :valid, as: :select, collection: [[  'Valid', true], ['Invalid', false]]
  filter :sms_pumping_risk_level, as: :select, collection: ['low', 'medium', 'high'], label: "Fraud Risk"
  filter :sms_pumping_risk_score, label: "Risk Score (0-100)"
  filter :sms_pumping_number_blocked, as: :select, collection: [['Blocked', true], ['Not Blocked', false]]
  filter :caller_name, label: "Caller Name (CNAM)"
  filter :caller_type, as: :select, collection: ['business', 'consumer']
  filter :is_business, as: :select, collection: [['Business', true], ['Consumer', false]], label: "Contact Type"
  filter :business_name, label: "Business Name"
  filter :business_type, as: :select, label: "Business Type"
  filter :business_industry, as: :select, label: "Industry"
  filter :business_employee_range, as: :select, collection: ['1-10', '11-50', '51-200', '201-500', '501-1000', '1001-5000', '5001-10000', '10000+'], label: "Company Size"
  filter :business_revenue_range, as: :select, collection: ['$0-$1M', '$1M-$10M', '$10M-$50M', '$50M-$100M', '$100M-$500M', '$500M-$1B', '$1B+'], label: "Revenue Range"
  filter :business_city, label: "Business City"
  filter :business_state, label: "Business State"
  filter :business_country, as: :select, label: "Business Country"
  filter :business_enriched, as: :select, collection: [['Enriched', true], ['Not Enriched', false]], label: "Enrichment Status"
  filter :error_code
  filter :lookup_performed_at
  filter :created_at
  
  # Email enrichment filters
  filter :email, label: "Email Address"
  filter :email_verified, as: :select, collection: [['Verified', true], ['Not Verified', false]], label: "Email Status"
  filter :email_score, label: "Email Quality Score (0-100)"
  filter :first_name, label: "First Name"
  filter :last_name, label: "Last Name"
  filter :position, label: "Job Title/Position"
  filter :department, label: "Department"
  filter :seniority, as: :select, label: "Seniority Level"
  
  # Duplicate detection filters
  filter :is_duplicate, as: :select, collection: [['Is Duplicate', true], ['Unique', false]], label: "Duplicate Status"
  filter :data_quality_score, label: "Data Quality Score (0-100)"
  filter :completeness_percentage, label: "Data Completeness %"
  
  # ========================================
  # Index View (Main Table)
  # ========================================
  index do
    selectable_column
    id_column
    
    column "Phone Number", :raw_phone_number
    
    column "Formatted", :formatted_phone_number do |contact|
      contact.formatted_phone_number || span("Not processed", class: "empty")
    end
    
    column "Status" do |contact|
      status_tag contact.status, class: contact.status
    end
    
    column "Carrier" do |contact|
      contact.carrier_name || span("—", class: "empty")
    end
    
    column "Type" do |contact|
      if contact.device_type
        status_tag contact.device_type, class: contact.device_type
      else
        span "—", class: "empty"
      end
    end

    column "Fraud Risk", :sms_pumping_risk_level do |contact|
      if contact.sms_pumping_number_blocked
        status_tag "Blocked", class: "error"
      elsif contact.sms_pumping_risk_level
        case contact.sms_pumping_risk_level
        when 'high'
          status_tag "High (#{contact.sms_pumping_risk_score})", class: "error"
        when 'medium'
          status_tag "Medium (#{contact.sms_pumping_risk_score})", class: "warning"
        when 'low'
          status_tag "Low (#{contact.sms_pumping_risk_score})", class: "ok"
        end
      else
        span "—", class: "empty"
      end
    end

    column "Valid" do |contact|
      if contact.valid.nil?
        span "—", class: "empty"
      elsif contact.valid
        status_tag "Yes", class: "ok"
      else
        status_tag "No", class: "error"
      end
    end

    column "Business", :business_name do |contact|
      if contact.business?
        div do
          if contact.business_name.present?
            strong contact.business_name, style: "display: block; color: #2c3e50;"
          end
          if contact.business_employee_range.present?
            small contact.business_size_category, style: "color: #7f8c8d; display: block;"
          end
          if !contact.business_enriched?
            status_tag "Not Enriched", class: "warning", style: "margin-top: 5px;"
          end
        end
      else
        span "—", class: "empty"
      end
    end

    column "Email", :email do |contact|
      if contact.email.present?
        div do
          span contact.email, style: "display: block; font-family: monospace; font-size: 12px;"
          if contact.email_verified
            status_tag "Verified", class: "ok", style: "margin-top: 3px;"
          elsif contact.email_verified == false
            status_tag "Invalid", class: "error", style: "margin-top: 3px;"
          end
        end
      else
        span "—", class: "empty"
      end
    end

    column "Quality", :data_quality_score do |contact|
      if contact.data_quality_score
        score = contact.data_quality_score
        color = if score >= 80
                  "#28a745"
                elsif score >= 60
                  "#ffc107"
                else
                  "#dc3545"
                end
        div do
          strong "#{score}/100", style: "color: #{color}; display: block;"
          if contact.is_duplicate
            status_tag "Duplicate", class: "error", style: "margin-top: 3px;"
          end
        end
      else
        span "—", class: "empty"
      end
    end
    
    column "Processed At" do |contact|
      contact.lookup_performed_at&.strftime("%b %d, %Y %H:%M") || span("—", class: "empty")
    end
    
    column "Error" do |contact|
      if contact.error_code.present?
        span truncate(contact.error_code, length: 40), title: contact.error_code, style: "color: #dc3545;"
      else
        span "—", class: "empty"
      end
    end
    
    actions defaults: true do |contact|
      if contact.status == 'failed' && contact.retriable?
        link_to 'Retry', retry_admin_contact_path(contact), method: :post, class: "member_link"
      end
      if contact.lookup_completed? && !contact.business_enriched?
        link_to 'Enrich', enrich_business_admin_contact_path(contact), method: :post, class: "member_link"
      end
      if contact.lookup_completed? && !contact.email_enriched?
        link_to 'Find Email', enrich_email_admin_contact_path(contact), method: :post, class: "member_link"
      end
      if contact.lookup_completed? && !contact.duplicate_checked_at
        link_to 'Check Dupes', check_duplicates_admin_contact_path(contact), method: :post, class: "member_link"
      end
    end
  end
  
  # ========================================
  # Show Page (Detail View)
  # ========================================
  show do
    attributes_table do
      row :id
      row :status do |contact|
        status_tag contact.status, class: contact.status
      end
      row :raw_phone_number
      row :formatted_phone_number
      row :valid do |contact|
        status_tag(contact.valid ? "Valid" : "Invalid", class: contact.valid ? "ok" : "error") unless contact.valid.nil?
      end
      row :validation_errors do |contact|
        if contact.validation_errors.present? && contact.validation_errors.any?
          contact.validation_errors.join(", ")
        else
          "None"
        end
      end
      row :country_code
      row :calling_country_code
      row :lookup_performed_at
      row :created_at
      row :updated_at
    end

    panel "📡 Line Type Intelligence" do
      attributes_table_for contact do
        row :line_type do |c|
          status_tag c.line_type_display if c.line_type
        end
        row :line_type_confidence
        row :carrier_name
        row :device_type do |c|
          span c.device_type, style: "color: #6c757d;" if c.device_type
        end
        row :mobile_country_code
        row :mobile_network_code
      end
    end

    panel "👤 Caller Identification (CNAM)" do
      attributes_table_for contact do
        row :caller_name do |c|
          c.caller_name || span("Not available (US only)", style: "color: #6c757d;")
        end
        row :caller_type do |c|
          if c.caller_type
            status_tag c.caller_type.titleize, class: c.caller_type
          else
            span "—", class: "empty"
          end
        end
      end
    end

    panel "🛡️ SMS Pumping Fraud Risk" do
      attributes_table_for contact do
        row "Risk Assessment" do |c|
          if c.sms_pumping_number_blocked
            status_tag "BLOCKED", class: "error"
          elsif c.sms_pumping_risk_level
            case c.sms_pumping_risk_level
            when 'high'
              status_tag "HIGH RISK", class: "error"
            when 'medium'
              status_tag "MEDIUM RISK", class: "warning"
            when 'low'
              status_tag "LOW RISK", class: "ok"
            end
          else
            span "Not assessed", style: "color: #6c757d;"
          end
        end
        row :sms_pumping_risk_score do |c|
          if c.sms_pumping_risk_score
            "#{c.sms_pumping_risk_score}/100"
          else
            "—"
          end
        end
        row :sms_pumping_carrier_risk_category do |c|
          if c.sms_pumping_carrier_risk_category
            status_tag c.sms_pumping_carrier_risk_category.upcase, 
                      class: c.sms_pumping_carrier_risk_category
          end
        end
        row :sms_pumping_number_blocked do |c|
          if c.sms_pumping_number_blocked.nil?
            "—"
          else
            status_tag(c.sms_pumping_number_blocked ? "Yes" : "No", 
                      class: c.sms_pumping_number_blocked ? "error" : "ok")
          end
        end
      end
    end

    panel "🏢 Business Intelligence" do
      if contact.business?
        attributes_table_for contact do
          row "Business Status" do |c|
            status_tag "Business Contact", class: "ok"
          end

          row "Enrichment Status" do |c|
            if c.business_enriched?
              div do
                status_tag "Enriched", class: "ok"
                if c.business_enrichment_provider.present?
                  span " via #{c.business_enrichment_provider.titleize}", style: "color: #6c757d; margin-left: 10px;"
                end
                if c.business_enriched_at.present?
                  span " on #{c.business_enriched_at.strftime('%b %d, %Y')}", style: "color: #6c757d; margin-left: 5px;"
                end
              end
            else
              status_tag "Not Enriched", class: "warning"
            end
          end

          row :business_name do |c|
            if c.business_name.present?
              strong c.business_name, style: "font-size: 16px;"
            else
              "—"
            end
          end

          row :business_legal_name

          row :business_type do |c|
            status_tag c.business_type.titleize if c.business_type
          end

          row :business_category
          row :business_industry do |c|
            status_tag c.business_industry if c.business_industry
          end

          row "Company Size" do |c|
            if c.business_employee_count
              "#{c.business_employee_count.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} employees (#{c.business_size_category})"
            elsif c.business_employee_range
              c.business_size_category
            else
              "—"
            end
          end

          row "Annual Revenue" do |c|
            if c.business_annual_revenue
              "$#{(c.business_annual_revenue.to_f / 1_000_000).round(1)}M (#{c.business_revenue_range})"
            elsif c.business_revenue_range
              c.business_revenue_range
            else
              "—"
            end
          end

          row "Founded" do |c|
            if c.business_founded_year
              "#{c.business_founded_year} (#{c.business_age} years old)"
            else
              "—"
            end
          end

          row "Confidence Score" do |c|
            if c.business_confidence_score
              "#{c.business_confidence_score}/100"
            else
              "—"
            end
          end
        end
      else
        para "This contact is not identified as a business.", style: "color: #6c757d; text-align: center; padding: 30px;"
      end
    end

    panel "📍 Business Location" do
      if contact.business? && contact.business_enriched?
        attributes_table_for contact do
          row :business_address
          row :business_city
          row :business_state
          row :business_country
          row :business_postal_code

          row "Full Address" do |c|
            parts = [c.business_address, c.business_city, c.business_state, c.business_postal_code, c.business_country].compact
            if parts.any?
              parts.join(", ")
            else
              "—"
            end
          end
        end
      else
        para "No business location data available.", style: "color: #6c757d; text-align: center; padding: 20px;"
      end
    end

    panel "🌐 Business Online Presence" do
      if contact.business? && contact.business_enriched?
        attributes_table_for contact do
          row :business_website do |c|
            if c.business_website
              link_to c.business_website, "https://#{c.business_website}", target: "_blank"
            else
              "—"
            end
          end

          row :business_email_domain do |c|
            if c.business_email_domain
              span "@#{c.business_email_domain}", style: "font-family: monospace;"
            else
              "—"
            end
          end

          row :business_linkedin_url do |c|
            if c.business_linkedin_url
              link_to "View LinkedIn Profile", c.business_linkedin_url, target: "_blank"
            else
              "—"
            end
          end

          row :business_twitter_handle do |c|
            if c.business_twitter_handle
              link_to "@#{c.business_twitter_handle}", "https://twitter.com/#{c.business_twitter_handle}", target: "_blank"
            else
              "—"
            end
          end
        end
      else
        para "No online presence data available.", style: "color: #6c757d; text-align: center; padding: 20px;"
      end
    end

    panel "📝 Business Description & Tags" do
      if contact.business? && contact.business_enriched?
        if contact.business_description.present?
          div style: "background: #f8f9fa; padding: 15px; border-radius: 8px; margin-bottom: 15px;" do
            para contact.business_description, style: "margin: 0; line-height: 1.6;"
          end
        end

        if contact.business_tags.present? && contact.business_tags.any?
          div do
            strong "Tags: "
            contact.business_tags.each do |tag|
              status_tag tag, class: "default", style: "margin: 2px;"
            end
          end
        end

        if contact.business_tech_stack.present? && contact.business_tech_stack.any?
          div style: "margin-top: 15px;" do
            strong "Technology Stack: "
            contact.business_tech_stack.each do |tech|
              status_tag tech, class: "ok", style: "margin: 2px;"
            end
          end
        end

        if !contact.business_description.present? && !contact.business_tags.any? && !contact.business_tech_stack.any?
          para "No description or tags available.", style: "color: #6c757d;"
        end
      else
        para "No business description data available.", style: "color: #6c757d; text-align: center; padding: 20px;"
      end
    end

    panel "✉️ Email Enrichment" do
      attributes_table_for contact do
        row "Enrichment Status" do |c|
          if c.email_enriched?
            div do
              status_tag "Email Found", class: "ok"
              if c.email_enrichment_provider.present?
                span " via #{c.email_enrichment_provider.titleize}", style: "color: #6c757d; margin-left: 10px;"
              end
              if c.email_enriched_at.present?
                span " on #{c.email_enriched_at.strftime('%b %d, %Y')}", style: "color: #6c757d; margin-left: 5px;"
              end
            end
          else
            status_tag "Not Enriched", class: "warning"
          end
        end

        row :email do |c|
          if c.email.present?
            div do
              link_to c.email, "mailto:#{c.email}", style: "font-family: monospace;"
              if c.email_verified
                status_tag "Verified", class: "ok", style: "margin-left: 10px;"
              elsif c.email_verified == false
                status_tag "Invalid", class: "error", style: "margin-left: 10px;"
              end
            end
          else
            "—"
          end
        end

        row :email_status do |c|
          if c.email_status
            case c.email_status
            when 'valid'
              status_tag "Valid", class: "ok"
            when 'invalid'
              status_tag "Invalid", class: "error"
            when 'unknown'
              status_tag "Unknown", class: "warning"
            when 'catch_all'
              status_tag "Catch-All", class: "warning"
            when 'disposable'
              status_tag "Disposable", class: "error"
            else
              c.email_status.titleize
            end
          else
            "—"
          end
        end

        row :email_score do |c|
          if c.email_score
            score = c.email_score
            color = score >= 80 ? "#28a745" : (score >= 60 ? "#ffc107" : "#dc3545")
            span "#{score}/100", style: "color: #{color}; font-weight: bold;"
          else
            "—"
          end
        end

        row "Additional Emails" do |c|
          if c.additional_emails.present? && c.additional_emails.any?
            c.additional_emails.join(", ")
          else
            "—"
          end
        end
      end
    end

    panel "👤 Contact Person Information" do
      if contact.email_enriched?
        attributes_table_for contact do
          row "Full Name" do |c|
            if c.full_name.present?
              strong c.full_name, style: "font-size: 16px;"
            elsif c.first_name.present? || c.last_name.present?
              "#{c.first_name} #{c.last_name}".strip
            else
              "—"
            end
          end

          row :first_name
          row :last_name
          row :position
          row :department
          row :seniority do |c|
            status_tag c.seniority.titleize if c.seniority
          end

          row "Social Profiles" do |c|
            profiles = []
            profiles << link_to("LinkedIn", c.linkedin_url, target: "_blank") if c.linkedin_url.present?
            profiles << link_to("Twitter", c.twitter_url, target: "_blank") if c.twitter_url.present?
            profiles << link_to("Facebook", c.facebook_url, target: "_blank") if c.facebook_url.present?
            
            if profiles.any?
              safe_join(profiles, " | ")
            else
              "—"
            end
          end
        end
      else
        para "No contact person information available.", style: "color: #6c757d; text-align: center; padding: 20px;"
      end
    end

    panel "🔍 Duplicate Detection" do
      attributes_table_for contact do
        row "Duplicate Status" do |c|
          if c.is_duplicate
            div do
              status_tag "This is a Duplicate", class: "error"
              if c.duplicate_of_id
                link_to "View Primary Contact", admin_contact_path(c.duplicate_of_id), 
                       class: "button", style: "margin-left: 10px;"
              end
            end
          else
            status_tag "Unique Contact", class: "ok"
          end
        end

        row :duplicate_confidence do |c|
          if c.duplicate_confidence
            "#{c.duplicate_confidence}%"
          else
            "—"
          end
        end

        row "Duplicate Check" do |c|
          if c.duplicate_checked_at
            "Checked on #{c.duplicate_checked_at.strftime('%b %d, %Y %H:%M')}"
          else
            "Not checked yet"
          end
        end

        row "Data Quality Score" do |c|
          if c.data_quality_score
            score = c.data_quality_score
            color = score >= 80 ? "#28a745" : (score >= 60 ? "#ffc107" : "#dc3545")
            span "#{score}/100", style: "color: #{color}; font-weight: bold;"
          else
            "—"
          end
        end

        row "Data Completeness" do |c|
          if c.completeness_percentage
            "#{c.completeness_percentage}%"
          else
            "—"
          end
        end

        row "Potential Duplicates" do |c|
          duplicates = c.find_potential_duplicates
          if duplicates.any?
            div do
              duplicates.first(5).each do |dup|
                div style: "margin-bottom: 10px; padding: 10px; background: #fff3cd; border-radius: 4px;" do
                  div do
                    link_to dup[:contact].business_display_name, admin_contact_path(dup[:contact]), 
                           style: "font-weight: bold; margin-right: 10px;"
                    status_tag "#{dup[:confidence]}% match", 
                              class: dup[:confidence] >= 80 ? "error" : "warning"
                  end
                  small "Reason: #{dup[:reason]}", style: "color: #6c757d;"
                end
              end
              if duplicates.count > 5
                para "...and #{duplicates.count - 5} more", style: "color: #6c757d; margin-top: 10px;"
              end
            end
          else
            "No potential duplicates found"
          end
        end

        row "Merge History" do |c|
          if c.merge_history.present? && c.merge_history.any?
            div do
              c.merge_history.each do |merge|
                div style: "margin-bottom: 5px;" do
                  text_node "Merged contact ##{merge['contact_id']} "
                  small "(#{Time.parse(merge['merged_at']).strftime('%b %d, %Y')})", style: "color: #6c757d;"
                end
              end
            end
          else
            "No merge history"
          end
        end
      end
    end

    panel "⚠️ Error Information" do
      attributes_table_for contact do
        row :error_code do |c|
          span c.error_code, style: "color: #dc3545;" if c.error_code
        end
      end
    end
    
    panel "Additional Information" do
      attributes_table_for contact do
        row "Retriable?" do |c|
          status_tag(c.retriable? ? "Yes" : "No", class: c.retriable? ? "yes" : "no")
        end
        row "Permanent Failure?" do |c|
          if c.status == 'failed'
            status_tag(c.send(:permanent_failure?) ? "Yes" : "No", class: c.send(:permanent_failure?) ? "yes" : "no")
          else
            "N/A"
          end
        end
      end
    end
    
    active_admin_comments
  end
  
  # ========================================
  # Form (Edit/New)
  # ========================================
  form do |f|
    f.inputs "Contact Details" do
      f.input :raw_phone_number, 
              label: "Phone Number",
              placeholder: "+14155551234",
              hint: "E.164 format recommended (e.g., +14155551234)"
      f.input :status, 
              as: :select, 
              collection: Contact::STATUSES,
              hint: "Status is automatically managed by the lookup process"
    end
    f.actions
  end
  
  # ========================================
  # Batch Actions
  # ========================================
  batch_action :reprocess, confirm: "Reprocess selected contacts?" do |ids|
    contacts = Contact.where(id: ids)
    count = 0
    
    contacts.each do |contact|
      next if contact.status == 'completed'
      contact.update(status: 'pending')
      LookupRequestJob.perform_later(contact)
      count += 1
    end
    
    redirect_to collection_path, notice: "#{count} contacts queued for reprocessing"
  end
  
  batch_action :mark_pending, confirm: "Mark selected contacts as pending?" do |ids|
    Contact.where(id: ids).update_all(status: 'pending')
    redirect_to collection_path, notice: "#{ids.count} contacts marked as pending"
  end
  
  batch_action :delete_all, confirm: "⚠️ Delete ALL contacts? This cannot be undone!" do
    Contact.delete_all
    redirect_to collection_path, alert: "All contacts have been deleted"
  end
  
  # ========================================
  # Member Actions
  # ========================================
  member_action :retry, method: :post do
    resource.update(status: 'pending')
    LookupRequestJob.perform_later(resource)
    redirect_to resource_path, notice: "Contact queued for retry"
  end

  member_action :enrich_business, method: :post do
    if resource.lookup_completed?
      BusinessEnrichmentJob.perform_later(resource)
      redirect_to resource_path, notice: "Business enrichment queued"
    else
      redirect_to resource_path, alert: "Complete phone lookup first before enriching business data"
    end
  end
  
  # ========================================
  # CSV/Excel Export Configuration
  # ========================================
  csv do
    column :id
    column :raw_phone_number
    column :formatted_phone_number
    column :status
    column :valid
    column :country_code
    column :calling_country_code
    column :line_type
    column :carrier_name
    column :device_type
    column :mobile_country_code
    column :mobile_network_code
    column :caller_name
    column :caller_type
    column :sms_pumping_risk_score
    column :sms_pumping_risk_level
    column :sms_pumping_carrier_risk_category
    column :sms_pumping_number_blocked
    column :is_business
    column :business_name
    column :business_legal_name
    column :business_type
    column :business_category
    column :business_industry
    column :business_employee_count
    column :business_employee_range
    column :business_annual_revenue
    column :business_revenue_range
    column :business_founded_year
    column :business_address
    column :business_city
    column :business_state
    column :business_country
    column :business_postal_code
    column :business_website
    column :business_email_domain
    column :business_linkedin_url
    column :business_twitter_handle
    column :business_description
    column :business_enriched
    column :business_enrichment_provider
    column :business_confidence_score
    column :error_code
    column :lookup_performed_at
    column :created_at
    column :updated_at
  end
  
  # ========================================
  # Permissions
  # ========================================
  permit_params :raw_phone_number, :formatted_phone_number, :mobile_network_code, 
                :error_code, :mobile_country_code, :carrier_name, :device_type, :status,
                :valid, :country_code, :calling_country_code, :line_type,
                :caller_name, :caller_type, :sms_pumping_risk_score, :sms_pumping_risk_level
end
