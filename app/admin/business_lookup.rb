ActiveAdmin.register_page "Business Lookup" do
  menu priority: 3, label: "Business Lookup"

  content title: "Business Lookup by Zipcode" do
    # Check if feature is enabled
    credentials = TwilioCredential.current

    unless credentials&.enable_zipcode_lookup
      panel "⚠️ Business Lookup Not Enabled" do
        para "Business lookup by zipcode is not enabled. Please configure it in ", style: "color: #856404; font-size: 16px;"
        link_to "Twilio Settings", admin_twilio_credentials_path, style: "font-weight: bold; font-size: 16px;"
        para " ", style: "margin-top: 15px;"
        para "You'll need to:", style: "font-weight: bold; margin-top: 15px;"
        ul do
          li "Enable 'Zipcode Business Lookup' toggle"
          li "Add Google Places API key OR Yelp API key"
          li "Configure results per zipcode (default: 20)"
        end
      end
      next
    end

    # Instructions Panel
    panel "📝 How to Use Business Lookup" do
      div style: "background: #e7f3ff; padding: 20px; border-radius: 8px;" do
        h3 "Find Businesses by Zipcode", style: "margin-top: 0;"

        para "Search for businesses in specific zipcodes and automatically import them into your contacts:", style: "margin: 10px 0;"

        ul do
          li do
            strong "Single Lookup: "
            span "Enter one zipcode to find businesses in that area"
          end
          li do
            strong "Bulk Lookup: "
            span "Enter multiple zipcodes (one per line) to process many areas at once"
          end
          li do
            strong "Duplicate Prevention: "
            span "Existing businesses are automatically updated, not duplicated"
          end
          li do
            strong "Auto-Enrichment: "
            span "New businesses are automatically enriched with phone lookup and email data"
          end
        end

        div style: "margin-top: 15px; padding: 10px; background: #fff3cd; border-left: 4px solid #ffc107; border-radius: 4px;" do
          strong "💡 Tip: "
          span "Results per zipcode: #{credentials.results_per_zipcode} businesses. Change this in Twilio Settings."
        end
      end
    end

    columns do
      # Single Zipcode Lookup
      column do
        panel "🎯 Single Zipcode Lookup" do
          form action: admin_business_lookup_lookup_single_path, method: :post do |f|
            f.input type: :hidden, name: :authenticity_token, value: form_authenticity_token

            div class: "input string required", style: "margin-bottom: 20px;" do
              label "Zipcode", for: "zipcode", class: "label"
              input type: "text",
                    name: "zipcode",
                    id: "zipcode",
                    placeholder: "e.g., 90210",
                    pattern: "\\d{5}",
                    required: true,
                    style: "width: 100%; padding: 10px; font-size: 16px; font-family: monospace;"
              span "5-digit US zipcode", class: "inline-hints", style: "color: #6c757d; font-size: 14px;"
            end

            div class: "actions" do
              input type: "submit",
                    value: "🔍 Search Businesses",
                    class: "button primary",
                    style: "font-size: 16px; padding: 12px 30px;"
            end
          end

          div style: "margin-top: 20px; padding: 15px; background: #d1ecf1; border-left: 4px solid #0c5460; border-radius: 4px;" do
            strong "How it works:"
            ul style: "margin: 10px 0 0 20px;" do
              li "Searches business directories for the zipcode"
              li "Checks each business against existing contacts"
              li "Creates new contacts or updates existing ones"
              li "Queues automatic enrichment (phone + email)"
            end
          end
        end
      end

      # Bulk Zipcode Lookup
      column do
        panel "📦 Bulk Zipcode Lookup" do
          form action: admin_business_lookup_lookup_bulk_path, method: :post do |f|
            f.input type: :hidden, name: :authenticity_token, value: form_authenticity_token

            div class: "input text required", style: "margin-bottom: 20px;" do
              label "Zipcodes (one per line)", for: "zipcodes", class: "label"
              textarea name: "zipcodes",
                       id: "zipcodes",
                       rows: 8,
                       placeholder: "90210\n10001\n60601\n77001",
                       required: true,
                       style: "width: 100%; padding: 10px; font-size: 14px; font-family: monospace;"
              span "Enter multiple 5-digit US zipcodes, one per line", class: "inline-hints", style: "color: #6c757d; font-size: 14px;"
            end

            div class: "actions" do
              input type: "submit",
                    value: "🚀 Start Bulk Lookup",
                    class: "button primary",
                    style: "font-size: 16px; padding: 12px 30px; background: #667eea;"
            end
          end

          div style: "margin-top: 20px; padding: 15px; background: #fff3cd; border-left: 4px solid #ffc107; border-radius: 4px;" do
            strong "⚠️ Note:"
            para "Bulk lookups process in the background. You'll see results in the history below.", style: "margin: 5px 0 0 0;"
          end
        end
      end
    end

    # Statistics Panel
    panel "📊 Lookup Statistics" do
      total_lookups = ZipcodeLookup.count
      completed_lookups = ZipcodeLookup.completed.count
      failed_lookups = ZipcodeLookup.failed.count
      pending_lookups = ZipcodeLookup.pending.count + ZipcodeLookup.processing.count

      total_found = ZipcodeLookup.completed.sum(:businesses_found)
      total_imported = ZipcodeLookup.completed.sum(:businesses_imported)
      total_updated = ZipcodeLookup.completed.sum(:businesses_updated)

      if total_lookups > 0
        attributes_table_for nil do
          row("Total Lookups") { total_lookups }
          row("Completed") do
            div do
              status_tag "#{completed_lookups} completed", class: "ok"
              if failed_lookups > 0
                status_tag "#{failed_lookups} failed", class: "error", style: "margin-left: 10px;"
              end
              if pending_lookups > 0
                status_tag "#{pending_lookups} in progress", class: "warning", style: "margin-left: 10px;"
              end
            end
          end
          row("Businesses Found") { total_found }
          row("New Businesses Imported") do
            span "#{total_imported}", style: "font-weight: bold; color: #28a745; font-size: 16px;"
          end
          row("Existing Businesses Updated") do
            span "#{total_updated}", style: "font-weight: bold; color: #667eea; font-size: 16px;"
          end
        end
      else
        para "No lookups performed yet. Use the forms above to start searching for businesses.",
             style: "color: #6c757d; text-align: center; padding: 30px;"
      end
    end

    # Recent Lookup History
    panel "📜 Recent Lookup History" do
      recent_lookups = ZipcodeLookup.recent.limit(20)

      if recent_lookups.any?
        table_for recent_lookups do
          column("Zipcode") do |lookup|
            strong lookup.zipcode, style: "font-family: monospace; font-size: 14px;"
          end

          column("Status") do |lookup|
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

          column("Provider") do |lookup|
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
              "—"
            end
          end

          column("Results") do |lookup|
            if lookup.status == 'completed'
              div do
                div "Found: #{lookup.businesses_found}"
                div do
                  span "Imported: ", style: "color: #28a745;"
                  strong lookup.businesses_imported
                  span " | Updated: ", style: "color: #667eea; margin-left: 10px;"
                  strong lookup.businesses_updated
                end
              end
            elsif lookup.status == 'failed'
              span "Error", style: "color: #dc3545;"
            else
              "—"
            end
          end

          column("Duration") do |lookup|
            if lookup.duration
              "#{lookup.duration.round(1)}s"
            else
              "—"
            end
          end

          column("Created") do |lookup|
            lookup.created_at.strftime("%b %d, %H:%M")
          end

          column("Actions") do |lookup|
            if lookup.status == 'completed'
              link_to "View Businesses",
                     admin_contacts_path(q: { business_postal_code_eq: lookup.zipcode }),
                     class: "button"
            elsif lookup.status == 'failed' && lookup.error_message.present?
              # Safely escape error message for JavaScript context
              safe_message = lookup.error_message.to_s
                .gsub('\\', '\\\\\\\\')  # Escape backslashes first
                .gsub("'", "\\\\'")       # Escape single quotes
                .gsub("\n", '\\n')        # Escape newlines
                .gsub("\r", '\\r')        # Escape carriage returns
                .gsub('</script>', '<\\/script>')  # Prevent script injection
              link_to "View Error", "#",
                     onclick: "alert('#{safe_message}'); return false;",
                     class: "button",
                     style: "background: #dc3545;"
            end
          end
        end
      else
        para "No lookup history yet.", style: "color: #6c757d; text-align: center; padding: 30px;"
      end
    end
  end

  # ========================================
  # Page Actions
  # ========================================

  page_action :lookup_single, method: :post do
    zipcode = params[:zipcode].to_s.strip

    # Validate zipcode
    unless zipcode.match?(/\A\d{5}\z/)
      redirect_to admin_business_lookup_path, alert: "Invalid zipcode format. Please enter a 5-digit US zipcode."
      return
    end

    # Create lookup record
    zipcode_lookup = ZipcodeLookup.create!(
      zipcode: zipcode,
      status: 'pending'
    )

    # Queue job
    BusinessLookupJob.perform_later(zipcode_lookup.id)

    redirect_to admin_business_lookup_path,
                notice: "Business lookup started for zipcode #{zipcode}. Results will appear below shortly."
  end

  page_action :lookup_bulk, method: :post do
    zipcodes_text = params[:zipcodes].to_s
    zipcodes = zipcodes_text.split("\n").map(&:strip).reject(&:blank?)

    # Validate zipcodes
    invalid_zipcodes = zipcodes.reject { |z| z.match?(/\A\d{5}\z/) }
    if invalid_zipcodes.any?
      redirect_to admin_business_lookup_path,
                  alert: "Invalid zipcodes found: #{invalid_zipcodes.join(', ')}. All zipcodes must be 5 digits."
      return
    end

    if zipcodes.empty?
      redirect_to admin_business_lookup_path, alert: "Please enter at least one zipcode."
      return
    end

    # Create lookup records and queue jobs
    count = 0
    zipcodes.each do |zipcode|
      zipcode_lookup = ZipcodeLookup.create!(
        zipcode: zipcode,
        status: 'pending'
      )
      BusinessLookupJob.perform_later(zipcode_lookup.id)
      count += 1
    end

    redirect_to admin_business_lookup_path,
                notice: "Bulk lookup started for #{count} zipcodes. Processing in background..."
  end
end
