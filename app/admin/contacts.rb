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
  
  # ========================================
  # Filters
  # ========================================
  filter :status, as: :select, collection: Contact::STATUSES
  filter :device_type, as: :select, collection: ['mobile', 'landline', 'voip']
  filter :carrier_name
  filter :raw_phone_number
  filter :formatted_phone_number
  filter :error_code
  filter :lookup_performed_at
  filter :created_at
  
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
      row :carrier_name
      row :device_type do |contact|
        status_tag contact.device_type if contact.device_type
      end
      row :mobile_country_code
      row :mobile_network_code
      row :error_code do |contact|
        span contact.error_code, style: "color: #dc3545;" if contact.error_code
      end
      row :lookup_performed_at
      row :created_at
      row :updated_at
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
  
  # ========================================
  # CSV/Excel Export Configuration
  # ========================================
  csv do
    column :id
    column :raw_phone_number
    column :formatted_phone_number
    column :status
    column :carrier_name
    column :device_type
    column :mobile_country_code
    column :mobile_network_code
    column :error_code
    column :lookup_performed_at
    column :created_at
    column :updated_at
  end
  
  # ========================================
  # Permissions
  # ========================================
  permit_params :raw_phone_number, :formatted_phone_number, :mobile_network_code, 
                :error_code, :mobile_country_code, :carrier_name, :device_type, :status
end
