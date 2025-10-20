ActiveAdmin.register ZipcodeLookup do
  menu priority: 4, label: "Zipcode History", parent: "Business Lookup"

  # ========================================
  # Scopes
  # ========================================
  scope :all, default: true
  scope :completed, label: "✅ Completed"
  scope :failed, label: "❌ Failed"
  scope :processing, label: "⏳ Processing"
  scope :pending, label: "🕐 Pending"

  # ========================================
  # Filters
  # ========================================
  filter :zipcode
  filter :status, as: :select, collection: ZipcodeLookup::STATUSES
  filter :provider, as: :select, collection: ['google_places', 'yelp']
  filter :businesses_found
  filter :businesses_imported
  filter :businesses_updated
  filter :created_at

  # ========================================
  # Index View
  # ========================================
  index do
    selectable_column
    id_column

    column "Zipcode", :zipcode do |lookup|
      strong lookup.zipcode, style: "font-family: monospace; font-size: 14px;"
    end

    column "Status" do |lookup|
      case lookup.status
      when 'completed'
        status_tag "Completed", class: "ok"
      when 'failed'
        status_tag "Failed", class: "error"
      when 'processing'
        status_tag "Processing", class: "warning"
      when 'pending'
        status_tag "Pending", class: "default"
      end
    end

    column "Provider" do |lookup|
      if lookup.provider.present?
        case lookup.provider
        when 'google_places'
          "🗺️ Google Places"
        when 'yelp'
          "⭐ Yelp"
        else
          lookup.provider.titleize
        end
      else
        span "—", class: "empty"
      end
    end

    column "Found" do |lookup|
      lookup.businesses_found
    end

    column "Imported", :businesses_imported do |lookup|
      if lookup.businesses_imported > 0
        strong lookup.businesses_imported, style: "color: #28a745;"
      else
        lookup.businesses_imported
      end
    end

    column "Updated", :businesses_updated do |lookup|
      if lookup.businesses_updated > 0
        strong lookup.businesses_updated, style: "color: #667eea;"
      else
        lookup.businesses_updated
      end
    end

    column "Skipped", :businesses_skipped

    column "Duration" do |lookup|
      if lookup.duration
        "#{lookup.duration.round(1)}s"
      else
        span "—", class: "empty"
      end
    end

    column "Created" do |lookup|
      lookup.created_at.strftime("%b %d, %H:%M")
    end

    actions defaults: true do |lookup|
      if lookup.status == 'completed' && lookup.businesses_found > 0
        link_to "View Contacts",
               admin_contacts_path(q: { business_postal_code_eq: lookup.zipcode }),
               class: "member_link"
      end
    end
  end

  # ========================================
  # Show Page
  # ========================================
  show do
    attributes_table do
      row :id
      row :zipcode do |lookup|
        strong lookup.zipcode, style: "font-size: 18px; font-family: monospace;"
      end

      row :status do |lookup|
        case lookup.status
        when 'completed'
          status_tag "Completed", class: "ok"
        when 'failed'
          status_tag "Failed", class: "error"
        when 'processing'
          status_tag "Processing", class: "warning"
        when 'pending'
          status_tag "Pending", class: "default"
        end
      end

      row :provider do |lookup|
        if lookup.provider.present?
          case lookup.provider
          when 'google_places'
            "🗺️ Google Places API"
          when 'yelp'
            "⭐ Yelp Fusion API"
          else
            lookup.provider.titleize
          end
        else
          "Not determined yet"
        end
      end

      row :created_at
      row :lookup_started_at
      row :lookup_completed_at

      row "Duration" do |lookup|
        if lookup.duration
          "#{lookup.duration.round(2)} seconds"
        else
          "—"
        end
      end
    end

    panel "📊 Results Summary" do
      attributes_table_for zipcode_lookup do
        row "Businesses Found" do |lookup|
          strong lookup.businesses_found, style: "font-size: 20px; color: #667eea;"
        end

        row "New Businesses Imported" do |lookup|
          div do
            strong lookup.businesses_imported, style: "font-size: 20px; color: #28a745;"
            if lookup.businesses_found > 0
              pct = (lookup.businesses_imported.to_f / lookup.businesses_found * 100).round(1)
              span " (#{pct}%)", style: "color: #6c757d; margin-left: 10px;"
            end
          end
        end

        row "Existing Businesses Updated" do |lookup|
          div do
            strong lookup.businesses_updated, style: "font-size: 20px; color: #667eea;"
            if lookup.businesses_found > 0
              pct = (lookup.businesses_updated.to_f / lookup.businesses_found * 100).round(1)
              span " (#{pct}%)", style: "color: #6c757d; margin-left: 10px;"
            end
          end
        end

        row "Businesses Skipped" do |lookup|
          lookup.businesses_skipped
        end

        row "Success Rate" do |lookup|
          if lookup.businesses_found > 0
            rate = lookup.success_rate
            color = rate >= 80 ? "#28a745" : (rate >= 50 ? "#ffc107" : "#dc3545")
            span "#{rate}%", style: "font-weight: bold; color: #{color}; font-size: 18px;"
          else
            "—"
          end
        end
      end

      if zipcode_lookup.status == 'completed' && zipcode_lookup.businesses_found > 0
        div style: "margin-top: 20px;" do
          link_to "📞 View Imported Contacts in this Zipcode",
                 admin_contacts_path(q: { business_postal_code_eq: zipcode_lookup.zipcode }),
                 class: "button primary",
                 style: "font-size: 16px; padding: 12px 24px;"
        end
      end
    end

    if zipcode_lookup.search_params.present?
      panel "🔍 Search Parameters" do
        div style: "background: #f8f9fa; padding: 15px; border-radius: 8px; font-family: monospace; white-space: pre-wrap;" do
          JSON.pretty_generate(zipcode_lookup.search_params_hash)
        end
      end
    end

    if zipcode_lookup.error_message.present?
      panel "⚠️ Error Details" do
        div style: "background: #f8d7da; padding: 15px; border-radius: 8px; border-left: 4px solid #dc3545;" do
          strong "Error Message:", style: "color: #721c24; display: block; margin-bottom: 10px;"
          div style: "color: #721c24; font-family: monospace; white-space: pre-wrap;" do
            zipcode_lookup.error_message
          end
        end
      end
    end

    active_admin_comments
  end

  # ========================================
  # Batch Actions
  # ========================================
  batch_action :reprocess, confirm: "Reprocess selected zipcode lookups?" do |ids|
    lookups = ZipcodeLookup.where(id: ids)
    count = 0

    lookups.each do |lookup|
      # Create new lookup for the same zipcode
      new_lookup = ZipcodeLookup.create!(
        zipcode: lookup.zipcode,
        status: 'pending'
      )
      BusinessLookupJob.perform_later(new_lookup.id)
      count += 1
    end

    redirect_to collection_path, notice: "#{count} zipcode lookups queued for reprocessing"
  end

  batch_action :delete, confirm: "Delete selected zipcode lookup records?" do |ids|
    ZipcodeLookup.where(id: ids).destroy_all
    redirect_to collection_path, notice: "#{ids.count} zipcode lookup records deleted"
  end

  # ========================================
  # CSV Export
  # ========================================
  csv do
    column :id
    column :zipcode
    column :status
    column :provider
    column :businesses_found
    column :businesses_imported
    column :businesses_updated
    column :businesses_skipped
    column :lookup_started_at
    column :lookup_completed_at
    column :error_message
    column :created_at
    column :updated_at
  end

  # ========================================
  # Permissions
  # ========================================
  permit_params :zipcode, :status

  # ========================================
  # Form (for manual creation - optional)
  # ========================================
  form do |f|
    f.semantic_errors

    f.inputs "Zipcode Lookup" do
      f.input :zipcode,
              label: "Zipcode",
              placeholder: "90210",
              hint: "5-digit US zipcode"
    end

    f.actions do
      f.action :submit, label: "Create and Queue Lookup"
      f.action :cancel
    end
  end

  # ========================================
  # Controller Customization
  # ========================================
  controller do
    def create
      @zipcode_lookup = ZipcodeLookup.new(permitted_params[:zipcode_lookup])
      @zipcode_lookup.status = 'pending'

      if @zipcode_lookup.save
        BusinessLookupJob.perform_later(@zipcode_lookup.id)
        redirect_to resource_path(@zipcode_lookup),
                    notice: "Zipcode lookup created and queued for processing"
      else
        render :new
      end
    end
  end
end
