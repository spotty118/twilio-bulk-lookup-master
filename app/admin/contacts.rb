ActiveAdmin.register Contact do
  active_admin_import validate: true

  # ========================================
  # Menu & Configuration
  # ========================================
  menu priority: 2, label: 'Contacts'

  # ========================================
  # Scopes - Clean, no emojis
  # ========================================
  scope :all, default: true
  scope :pending
  scope :processing
  scope :completed
  scope :failed

  # Risk scopes
  scope :high_risk, group: :risk
  scope :medium_risk, group: :risk
  scope :low_risk, group: :risk

  # Type scopes
  scope :mobile, group: :type
  scope :landline, group: :type
  scope :voip, group: :type

  # Contact type
  scope :businesses, group: :contact
  scope :consumers, group: :contact

  # Line status (RPV)
  scope :connected, group: :line_status
  scope :disconnected, group: :line_status

  # Porting status (Scout)
  scope :ported, group: :porting
  scope :not_ported, group: :porting

  # Disable sidebar filters (using scopes at top instead)
  config.filters = false

  # Default sort order - ID ascending (1, 2, 3...)
  config.sort_order = 'id_asc'

  # ========================================
  # Index View - Simplified table
  # ========================================
  index do
    selectable_column
    id_column

    column 'Phone', :raw_phone_number, sortable: :raw_phone_number

    column 'Status' do |contact|
      status_tag contact.status, class: contact.status
    end

    column 'Type' do |contact|
      if contact.device_type
        status_tag contact.device_type
      else
        span '-', class: 'empty'
      end
    end

    column :line_status, sortable: :rpv_status do |contact|
      if contact.rpv_status.present?
        case contact.rpv_status.downcase
        when 'connected'
          status_tag 'Connected', class: 'ok'
        when 'disconnected'
          status_tag 'Disconnected', class: 'error'
        when 'pending', 'busy', 'unreachable'
          status_tag contact.rpv_status.titleize, class: 'warning'
        else
          status_tag contact.rpv_status, class: 'warning'
        end
      else
        span '-', class: 'empty'
      end
    end

    column 'Carrier' do |contact|
      contact.carrier_name || span('-', class: 'empty')
    end

    column 'Ported', sortable: :scout_ported do |contact|
      if contact.scout_ported == true
        status_tag 'Yes', class: 'warning'
      elsif contact.scout_ported == false
        status_tag 'No', class: 'ok'
      else
        span '-', class: 'empty'
      end
    end

    column 'Verizon', sortable: :verizon_5g_home_available do |contact|
      if contact.verizon_coverage_checked?
        if contact.verizon_5g_home_available
          status_tag '5G', class: 'ok'
        elsif contact.verizon_lte_home_available
          status_tag 'LTE', class: 'warning'
        elsif contact.verizon_fios_available
          status_tag 'Fios', class: 'ok'
        else
          status_tag 'No', class: 'error'
        end
      else
        span '-', class: 'empty'
      end
    end

    column 'Contact' do |contact|
      if contact.business?
        div do
          span contact.business_name || 'Business', style: 'font-weight: 500;'
        end
      elsif contact.email.present?
        span contact.email, style: 'font-size: 12px;'
      else
        span '-', class: 'empty'
      end
    end

    column 'Processed' do |contact|
      contact.lookup_performed_at&.strftime('%b %d') || span('-', class: 'empty')
    end

    actions defaults: true do |contact|
      if contact.status == 'failed' && contact.retriable?
        link_to 'Retry', retry_admin_contact_path(contact), method: :post, class: 'member_link'
      end
    end
  end

  # ========================================
  # Show Page - Organized panels
  # ========================================
  show do
    # Basic info
    attributes_table do
      row :id
      row :status do |c|
        status_tag c.status, class: c.status
      end
      row :raw_phone_number
      row :formatted_phone_number
      row :lookup_performed_at
    end

    # Line Type
    panel 'Line Information' do
      attributes_table_for contact do
        row :device_type do |c|
          status_tag c.device_type if c.device_type
        end
        row :line_type
        row :carrier_name
        row :country_code
      end
    end

    # Real Phone Validation (Line Status)
    if contact.rpv_status.present?
      panel 'Line Status (Real Phone Validation)' do
        attributes_table_for contact do
          row 'Status' do |c|
            case c.rpv_status&.downcase
            when 'connected'
              status_tag 'CONNECTED', class: 'ok'
            when 'disconnected'
              status_tag 'DISCONNECTED', class: 'error'
            when 'pending', 'busy', 'unreachable'
              status_tag c.rpv_status.upcase, class: 'warning'
            else
              status_tag c.rpv_status, class: 'warning'
            end
          end
          row 'Is Cell' do |c|
            case c.rpv_iscell
            when 'Y'
              status_tag 'Yes', class: 'ok'
            when 'N'
              status_tag 'No', class: 'warning'
            when 'V'
              status_tag 'VoIP', class: 'warning'
            else
              span c.rpv_iscell || '-', class: 'empty'
            end
          end
          row 'Carrier' do |c|
            c.rpv_carrier.presence || span('-', class: 'empty')
          end
          row 'Caller Name (CNAM)' do |c|
            c.rpv_cnam.presence || span('-', class: 'empty')
          end
          if contact.rpv_error_text.present?
            row 'Error' do |c|
              span c.rpv_error_text, style: 'color: #dc2626;'
            end
          end
        end
      end
    end

    # Porting Data (IceHook Scout)
    if contact.scout_ported.present? || contact.scout_operating_company_name.present?
      panel 'Porting Information (Scout)' do
        attributes_table_for contact do
          row 'Ported' do |c|
            if c.scout_ported == true
              status_tag 'YES - Number has been ported', class: 'warning'
            elsif c.scout_ported == false
              status_tag 'NO - Original carrier', class: 'ok'
            else
              span '-', class: 'empty'
            end
          end
          row 'Operating Company' do |c|
            c.scout_operating_company_name.presence || span('-', class: 'empty')
          end
          row 'Company Type' do |c|
            c.scout_operating_company_type.presence || span('-', class: 'empty')
          end
          row 'Location Routing Number' do |c|
            if c.scout_location_routing_number.present?
              code c.scout_location_routing_number, style: 'font-family: monospace;'
            else
              span '-', class: 'empty'
            end
          end
        end
      end
    end

    # Fraud Risk
    if contact.sms_pumping_risk_level.present?
      panel 'Fraud Assessment' do
        attributes_table_for contact do
          row 'Risk Level' do |c|
            case c.sms_pumping_risk_level
            when 'high'
              status_tag 'HIGH RISK', class: 'error'
            when 'medium'
              status_tag 'MEDIUM RISK', class: 'warning'
            when 'low'
              status_tag 'LOW RISK', class: 'ok'
            end
          end
          row :sms_pumping_risk_score do |c|
            "#{c.sms_pumping_risk_score}/100" if c.sms_pumping_risk_score
          end
          row 'Blocked' do |c|
            status_tag(c.sms_pumping_number_blocked ? 'Yes' : 'No',
                       class: c.sms_pumping_number_blocked ? 'error' : 'ok') unless c.sms_pumping_number_blocked.nil?
          end
        end
      end
    end

    # Business Info (if applicable)
    if contact.business?
      panel 'Business Details' do
        attributes_table_for contact do
          row :business_name
          row :business_type
          row :business_industry
          row 'Size' do |c|
            c.business_employee_range if c.business_employee_range
          end
          row :business_website do |c|
            link_to c.business_website, "https://#{c.business_website}", target: '_blank' if c.business_website
          end
          row 'Location' do |c|
            [c.business_city, c.business_state, c.business_country].compact.join(', ')
          end
        end
      end
    end

    # Email (if available)
    if contact.email.present?
      panel 'Email Information' do
        attributes_table_for contact do
          row :email do |c|
            div do
              link_to c.email, "mailto:#{c.email}"
              if c.email_verified
                status_tag 'Verified', class: 'ok', style: 'margin-left: 8px;'
              elsif c.email_verified == false
                status_tag 'Invalid', class: 'error', style: 'margin-left: 8px;'
              end
            end
          end
          row :first_name
          row :last_name
          row :position
        end
      end
    end

    # Consumer Address (if available)
    if contact.consumer? && contact.address_enriched?
      panel 'Address' do
        attributes_table_for contact do
          row 'Full Address' do |c|
            c.full_address if c.has_full_address?
          end
          row :address_type
          row 'Verified' do |c|
            status_tag(c.address_verified ? 'Yes' : 'No', class: c.address_verified ? 'ok' : 'warning')
          end
        end
      end
    end

    # Verizon Coverage (if checked)
    if contact.verizon_coverage_checked?
      panel 'Verizon Coverage' do
        attributes_table_for contact do
          row 'Available' do |c|
            if c.verizon_home_internet_available?
              status_tag 'Yes', class: 'ok'
            else
              status_tag 'No', class: 'error'
            end
          end
          row 'Products' do |c|
            div do
              status_tag 'Fios', class: 'ok' if c.verizon_fios_available
              status_tag '5G Home', class: 'ok' if c.verizon_5g_home_available
              status_tag 'LTE Home', class: 'warning' if c.verizon_lte_home_available
            end
          end
          row :estimated_download_speed
        end
      end
    end

    # Error (if failed)
    if contact.error_code.present?
      panel 'Error' do
        attributes_table_for contact do
          row :error_code do |c|
            span c.error_code, style: 'color: #dc2626;'
          end
          row 'Retriable' do |c|
            status_tag(c.retriable? ? 'Yes' : 'No', class: c.retriable? ? 'ok' : 'error')
          end
        end
      end
    end

    active_admin_comments
  end

  # ========================================
  # Form
  # ========================================
  form do |f|
    f.inputs 'Contact Details' do
      f.input :raw_phone_number,
              label: 'Phone Number',
              placeholder: '+14155551234',
              hint: 'E.164 format (e.g., +14155551234)'
      f.input :status,
              as: :select,
              collection: Contact::STATUSES
    end
    f.actions
  end

  # ========================================
  # Batch Actions
  # ========================================
  batch_action :reprocess, confirm: 'Reprocess selected contacts?' do |ids|
    contacts = Contact.where(id: ids)
    count = 0

    contacts.each do |contact|
      next unless contact.reset_for_reprocessing!

      LookupRequestJob.perform_later(contact.id)
      count += 1
    end

    redirect_to collection_path, notice: "#{count} contacts queued for reprocessing"
  end

  batch_action :mark_pending, confirm: 'Mark selected as pending?' do |ids|
    Contact.where(id: ids).update_all(status: 'pending')
    redirect_to collection_path, notice: "#{ids.count} contacts marked as pending"
  end

  # ========================================
  # Member Actions
  # ========================================
  member_action :retry, method: :post do
    if resource.reset_for_reprocessing!
      LookupRequestJob.perform_later(resource.id)
      redirect_to resource_path, notice: 'Contact queued for retry'
    else
      redirect_to resource_path, alert: 'Contact is already processing'
    end
  end

  member_action :enrich_business, method: :post do
    if resource.lookup_completed?
      BusinessEnrichmentJob.perform_later(resource.id)
      redirect_to resource_path, notice: 'Business enrichment queued'
    else
      redirect_to resource_path, alert: 'Complete phone lookup first'
    end
  end

  member_action :enrich_email, method: :post do
    if resource.lookup_completed?
      EmailEnrichmentJob.perform_later(resource.id)
      redirect_to resource_path, notice: 'Email enrichment queued'
    else
      redirect_to resource_path, alert: 'Complete phone lookup first'
    end
  end

  member_action :check_duplicates, method: :post do
    if resource.lookup_completed?
      DuplicateDetectionJob.perform_later(resource.id)
      redirect_to resource_path, notice: 'Duplicate detection queued'
    else
      redirect_to resource_path, alert: 'Complete phone lookup first'
    end
  end

  member_action :enrich_address, method: :post do
    if resource.consumer?
      AddressEnrichmentJob.perform_later(resource.id)
      redirect_to resource_path, notice: 'Address enrichment queued'
    else
      redirect_to resource_path, alert: 'Address enrichment is only for consumers'
    end
  end

  member_action :check_verizon_coverage, method: :post do
    if resource.consumer? && resource.has_full_address?
      VerizonCoverageCheckJob.perform_later(resource.id)
      redirect_to resource_path, notice: 'Verizon coverage check queued'
    elsif !resource.consumer?
      redirect_to resource_path, alert: 'Verizon check is only for consumers'
    else
      redirect_to resource_path, alert: 'Address required first'
    end
  end

  # ========================================
  # CSV Export
  # ========================================
  csv do
    column :id
    column :raw_phone_number
    column :formatted_phone_number
    column :status
    column :device_type
    column :carrier_name
    column :country_code
    column :sms_pumping_risk_level
    column :sms_pumping_risk_score
    column :is_business
    column :business_name
    column :business_industry
    column :email
    column :email_verified
    column :first_name
    column :last_name
    column :consumer_address
    column :consumer_city
    column :consumer_state
    column :consumer_postal_code
    column :verizon_5g_home_available
    column :verizon_lte_home_available
    column :verizon_fios_available
    column :rpv_status
    column :rpv_iscell
    column :rpv_carrier
    column :rpv_cnam
    column :scout_ported
    column :scout_location_routing_number
    column :scout_operating_company_name
    column :scout_operating_company_type
    column :error_code
    column :lookup_performed_at
    column :created_at
  end

  # ========================================
  # Permissions
  # ========================================
  permit_params :raw_phone_number, :status
end
