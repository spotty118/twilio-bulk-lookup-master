ActiveAdmin.register_page "API Connectors" do
  menu priority: 4, label: "API Connectors"

  content title: "API Connectors Dashboard" do
    credentials = TwilioCredential.first

    # If no credentials exist, show setup prompt
    unless credentials
      panel "⚠️ Setup Required" do
        div style: "text-align: center; padding: 40px;" do
          h2 "No API credentials configured yet", style: "color: #6c757d; margin-bottom: 20px;"
          para "Please configure your API credentials to start using the bulk lookup features."
          link_to "Configure Credentials →", new_admin_twilio_credential_path,
                  class: "button primary",
                  style: "margin-top: 20px; font-size: 16px; padding: 15px 30px;"
        end
      end
      return
    end

    # ========================================
    # Quick Overview Stats
    # ========================================
    div style: "background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 30px; border-radius: 12px; margin-bottom: 30px; color: white;" do
      h2 "API Integration Overview", style: "margin: 0 0 20px 0; color: white;"

      columns do
        column do
          div style: "text-align: center;" do
            h3 style: "font-size: 48px; margin: 0; color: white;" do
              total_apis = 11  # Total number of APIs
              configured_count = 0
              configured_count += 1 if credentials.account_sid.present?
              configured_count += 1 if credentials.clearbit_api_key.present?
              configured_count += 1 if credentials.numverify_api_key.present?
              configured_count += 1 if credentials.hunter_api_key.present?
              configured_count += 1 if credentials.zerobounce_api_key.present?
              configured_count += 1 if credentials.openai_api_key.present?
              configured_count += 1 if credentials.google_places_api_key.present?
              configured_count += 1 if credentials.yelp_api_key.present?
              configured_count += 1 if credentials.whitepages_api_key.present?
              configured_count += 1 if credentials.truecaller_api_key.present?
              # Verizon doesn't need an API key
              configured_count += 1

              configured_count.to_s
            end
            para "APIs Configured", style: "margin: 5px 0 0 0; opacity: 0.9; color: white;"
          end
        end

        column do
          div style: "text-align: center;" do
            h3 style: "font-size: 48px; margin: 0; color: white;" do
              enabled_features = 0
              enabled_features += 1 if credentials.enable_line_type_intelligence
              enabled_features += 1 if credentials.enable_caller_name
              enabled_features += 1 if credentials.enable_sms_pumping_risk
              enabled_features += 1 if credentials.enable_business_enrichment
              enabled_features += 1 if credentials.enable_email_enrichment
              enabled_features += 1 if credentials.enable_duplicate_detection
              enabled_features += 1 if credentials.enable_ai_features
              enabled_features += 1 if credentials.enable_zipcode_lookup
              enabled_features += 1 if credentials.enable_address_enrichment
              enabled_features += 1 if credentials.enable_verizon_coverage_check

              enabled_features.to_s
            end
            para "Features Enabled", style: "margin: 5px 0 0 0; opacity: 0.9; color: white;"
          end
        end

        column do
          div style: "text-align: center;" do
            h3 style: "font-size: 48px; margin: 0; color: white;" do
              Contact.completed.count.to_s
            end
            para "Successful Lookups", style: "margin: 5px 0 0 0; opacity: 0.9; color: white;"
          end
        end

        column do
          div style: "text-align: center;" do
            h3 style: "font-size: 48px; margin: 0; color: white;" do
              business_count = Contact.business_enriched.count
              business_count.to_s
            end
            para "Enriched Businesses", style: "margin: 5px 0 0 0; opacity: 0.9; color: white;"
          end
        end
      end
    end

    # ========================================
    # CORE APIS
    # ========================================
    panel "🔧 Core APIs", class: "api-section" do
      div style: "display: grid; grid-template-columns: repeat(auto-fit, minmax(350px, 1fr)); gap: 20px;" do

        # Twilio Lookup API
        div class: "api-card", style: "background: white; padding: 25px; border-radius: 12px; border: 2px solid #{credentials.account_sid.present? ? '#28a745' : '#dc3545'}; box-shadow: 0 2px 8px rgba(0,0,0,0.1);" do
          div style: "display: flex; justify-content: space-between; align-items: start; margin-bottom: 15px;" do
            div do
              h3 style: "margin: 0 0 5px 0; color: #333; font-size: 20px;" do
                "📞 Twilio Lookup v2"
              end
              para "Core phone validation & intelligence", style: "margin: 0; color: #6c757d; font-size: 14px;"
            end

            if credentials.account_sid.present?
              status_tag "CONFIGURED", class: "ok", style: "font-size: 12px;"
            else
              status_tag "NOT CONFIGURED", class: "error", style: "font-size: 12px;"
            end
          end

          if credentials.account_sid.present?
            div style: "background: #f8f9fa; padding: 12px; border-radius: 6px; margin-bottom: 12px; font-family: monospace; font-size: 12px;" do
              "Account: #{credentials.account_sid[0..5]}***#{credentials.account_sid[-4..]}"
            end

            div style: "margin-bottom: 12px;" do
              para "Enabled Data Packages:", style: "margin: 0 0 8px 0; font-weight: bold; font-size: 13px;"
              ul style: "margin: 0; padding-left: 20px; font-size: 13px;" do
                li "Line Type Intelligence" if credentials.enable_line_type_intelligence
                li "Caller Name (CNAM)" if credentials.enable_caller_name
                li "SMS Pumping Risk" if credentials.enable_sms_pumping_risk
                li "SIM Swap Detection" if credentials.enable_sim_swap
                li "Reassigned Number" if credentials.enable_reassigned_number
              end
            end

            # Test Twilio connection
            begin
              client = Twilio::REST::Client.new(credentials.account_sid, credentials.auth_token)
              account = client.api.accounts(credentials.account_sid).fetch
              div style: "padding: 10px; background: #d4edda; border-left: 4px solid #28a745; border-radius: 4px; margin-bottom: 12px;" do
                strong "✅ Connected", style: "color: #155724;"
                para "Account: #{account.friendly_name} (#{account.status})", style: "margin: 5px 0 0 0; font-size: 12px; color: #155724;"
              end
            rescue => e
              div style: "padding: 10px; background: #f8d7da; border-left: 4px solid #dc3545; border-radius: 4px; margin-bottom: 12px;" do
                strong "❌ Connection Failed", style: "color: #721c24;"
                para e.message, style: "margin: 5px 0 0 0; font-size: 11px; color: #721c24;"
              end
            end
          else
            div style: "padding: 15px; background: #fff3cd; border-left: 4px solid #ffc107; border-radius: 4px; margin-bottom: 12px;" do
              "⚠️ Twilio API is required for phone number lookups"
            end
          end

          link_to "⚙️ Configure", edit_admin_twilio_credential_path(credentials),
                  class: "button primary",
                  style: "width: 100%; text-align: center;"
        end
      end
    end

    # ========================================
    # BUSINESS INTELLIGENCE APIS
    # ========================================
    panel "🏢 Business Intelligence APIs", class: "api-section" do
      div style: "display: grid; grid-template-columns: repeat(auto-fit, minmax(350px, 1fr)); gap: 20px;" do

        # Clearbit API
        div class: "api-card", style: "background: white; padding: 25px; border-radius: 12px; border: 2px solid #{credentials.clearbit_api_key.present? ? '#28a745' : '#e9ecef'}; box-shadow: 0 2px 8px rgba(0,0,0,0.1);" do
          div style: "display: flex; justify-content: space-between; align-items: start; margin-bottom: 15px;" do
            div do
              h3 style: "margin: 0 0 5px 0; color: #333; font-size: 20px;" do
                "💼 Clearbit"
              end
              para "Premium business intelligence", style: "margin: 0; color: #6c757d; font-size: 14px;"
            end

            if credentials.clearbit_api_key.present?
              status_tag "CONFIGURED", class: "ok", style: "font-size: 12px;"
            else
              status_tag "OPTIONAL", class: "default", style: "font-size: 12px;"
            end
          end

          if credentials.clearbit_api_key.present?
            div style: "background: #f8f9fa; padding: 12px; border-radius: 6px; margin-bottom: 12px; font-family: monospace; font-size: 12px;" do
              "Key: sk-***#{credentials.clearbit_api_key[-4..]}"
            end

            div style: "margin-bottom: 12px;" do
              para "Provides:", style: "margin: 0 0 8px 0; font-weight: bold; font-size: 13px;"
              ul style: "margin: 0; padding-left: 20px; font-size: 13px;" do
                li "Company name & description"
                li "Employee count & revenue"
                li "Industry & category"
                li "Technology stack"
              end
            end

            if credentials.enable_business_enrichment
              div style: "padding: 10px; background: #d4edda; border-left: 4px solid #28a745; border-radius: 4px; margin-bottom: 12px;" do
                strong "✅ Business Enrichment Active", style: "color: #155724;"
                para "#{Contact.business_enriched.count} businesses enriched", style: "margin: 5px 0 0 0; font-size: 12px; color: #155724;"
              end
            else
              div style: "padding: 10px; background: #fff3cd; border-left: 4px solid #ffc107; border-radius: 4px; margin-bottom: 12px;" do
                "⚠️ Enable business enrichment to use this API"
              end
            end
          else
            div style: "padding: 15px; background: #f8f9fa; border-left: 4px solid #6c757d; border-radius: 4px; margin-bottom: 12px;" do
              "ℹ️ Optional: Provides premium business data"
            end
          end

          link_to "⚙️ Configure", edit_admin_twilio_credential_path(credentials, anchor: 'business_enrichment'),
                  class: "button",
                  style: "width: 100%; text-align: center;"
        end

        # NumVerify API
        div class: "api-card", style: "background: white; padding: 25px; border-radius: 12px; border: 2px solid #{credentials.numverify_api_key.present? ? '#28a745' : '#e9ecef'}; box-shadow: 0 2px 8px rgba(0,0,0,0.1);" do
          div style: "display: flex; justify-content: space-between; align-items: start; margin-bottom: 15px;" do
            div do
              h3 style: "margin: 0 0 5px 0; color: #333; font-size: 20px;" do
                "🔍 NumVerify"
              end
              para "Basic phone intelligence", style: "margin: 0; color: #6c757d; font-size: 14px;"
            end

            if credentials.numverify_api_key.present?
              status_tag "CONFIGURED", class: "ok", style: "font-size: 12px;"
            else
              status_tag "OPTIONAL", class: "default", style: "font-size: 12px;"
            end
          end

          if credentials.numverify_api_key.present?
            div style: "background: #f8f9fa; padding: 12px; border-radius: 6px; margin-bottom: 12px; font-family: monospace; font-size: 12px;" do
              "Key: ***#{credentials.numverify_api_key[-4..]}"
            end

            div style: "margin-bottom: 12px;" do
              para "Provides:", style: "margin: 0 0 8px 0; font-weight: bold; font-size: 13px;"
              ul style: "margin: 0; padding-left: 20px; font-size: 13px;" do
                li "Phone validation"
                li "Business detection"
                li "Carrier information"
              end
            end
          else
            div style: "padding: 15px; background: #f8f9fa; border-left: 4px solid #6c757d; border-radius: 4px; margin-bottom: 12px;" do
              "ℹ️ Optional: Fallback for business detection"
            end
          end

          link_to "⚙️ Configure", edit_admin_twilio_credential_path(credentials, anchor: 'business_enrichment'),
                  class: "button",
                  style: "width: 100%; text-align: center;"
        end
      end
    end

    # ========================================
    # EMAIL ENRICHMENT APIS
    # ========================================
    panel "✉️ Email Enrichment APIs", class: "api-section" do
      div style: "display: grid; grid-template-columns: repeat(auto-fit, minmax(350px, 1fr)); gap: 20px;" do

        # Hunter.io API
        div class: "api-card", style: "background: white; padding: 25px; border-radius: 12px; border: 2px solid #{credentials.hunter_api_key.present? ? '#28a745' : '#e9ecef'}; box-shadow: 0 2px 8px rgba(0,0,0,0.1);" do
          div style: "display: flex; justify-content: space-between; align-items: start; margin-bottom: 15px;" do
            div do
              h3 style: "margin: 0 0 5px 0; color: #333; font-size: 20px;" do
                "📧 Hunter.io"
              end
              para "Email finding & verification", style: "margin: 0; color: #6c757d; font-size: 14px;"
            end

            if credentials.hunter_api_key.present?
              status_tag "CONFIGURED", class: "ok", style: "font-size: 12px;"
            else
              status_tag "OPTIONAL", class: "default", style: "font-size: 12px;"
            end
          end

          if credentials.hunter_api_key.present?
            div style: "background: #f8f9fa; padding: 12px; border-radius: 6px; margin-bottom: 12px; font-family: monospace; font-size: 12px;" do
              "Key: ***#{credentials.hunter_api_key[-4..]}"
            end

            div style: "margin-bottom: 12px;" do
              para "Provides:", style: "margin: 0 0 8px 0; font-weight: bold; font-size: 13px;"
              ul style: "margin: 0; padding-left: 20px; font-size: 13px;" do
                li "Email discovery from phone"
                li "Email verification"
                li "Contact person details"
              end
            end

            if credentials.enable_email_enrichment
              div style: "padding: 10px; background: #d4edda; border-left: 4px solid #28a745; border-radius: 4px; margin-bottom: 12px;" do
                strong "✅ Email Enrichment Active", style: "color: #155724;"
                para "#{Contact.email_enriched.count} contacts with emails", style: "margin: 5px 0 0 0; font-size: 12px; color: #155724;"
              end
            else
              div style: "padding: 10px; background: #fff3cd; border-left: 4px solid #ffc107; border-radius: 4px; margin-bottom: 12px;" do
                "⚠️ Enable email enrichment to use this API"
              end
            end
          else
            div style: "padding: 15px; background: #f8f9fa; border-left: 4px solid #6c757d; border-radius: 4px; margin-bottom: 12px;" do
              "ℹ️ Optional: Find emails from phone numbers"
            end
          end

          link_to "⚙️ Configure", edit_admin_twilio_credential_path(credentials, anchor: 'email_enrichment'),
                  class: "button",
                  style: "width: 100%; text-align: center;"
        end

        # ZeroBounce API
        div class: "api-card", style: "background: white; padding: 25px; border-radius: 12px; border: 2px solid #{credentials.zerobounce_api_key.present? ? '#28a745' : '#e9ecef'}; box-shadow: 0 2px 8px rgba(0,0,0,0.1);" do
          div style: "display: flex; justify-content: space-between; align-items: start; margin-bottom: 15px;" do
            div do
              h3 style: "margin: 0 0 5px 0; color: #333; font-size: 20px;" do
                "✅ ZeroBounce"
              end
              para "Email verification service", style: "margin: 0; color: #6c757d; font-size: 14px;"
            end

            if credentials.zerobounce_api_key.present?
              status_tag "CONFIGURED", class: "ok", style: "font-size: 12px;"
            else
              status_tag "OPTIONAL", class: "default", style: "font-size: 12px;"
            end
          end

          if credentials.zerobounce_api_key.present?
            div style: "background: #f8f9fa; padding: 12px; border-radius: 6px; margin-bottom: 12px; font-family: monospace; font-size: 12px;" do
              "Key: ***#{credentials.zerobounce_api_key[-4..]}"
            end

            div style: "margin-bottom: 12px;" do
              para "Provides:", style: "margin: 0 0 8px 0; font-weight: bold; font-size: 13px;"
              ul style: "margin: 0; padding-left: 20px; font-size: 13px;" do
                li "Email deliverability check"
                li "Validation scores"
                li "Bounce risk assessment"
              end
            end
          else
            div style: "padding: 15px; background: #f8f9fa; border-left: 4px solid #6c757d; border-radius: 4px; margin-bottom: 12px;" do
              "ℹ️ Optional: Verify email deliverability"
            end
          end

          link_to "⚙️ Configure", edit_admin_twilio_credential_path(credentials, anchor: 'email_enrichment'),
                  class: "button",
                  style: "width: 100%; text-align: center;"
        end
      end
    end

    # ========================================
    # ADDRESS & COVERAGE APIS
    # ========================================
    panel "🏠 Address & Coverage APIs", class: "api-section" do
      div style: "display: grid; grid-template-columns: repeat(auto-fit, minmax(350px, 1fr)); gap: 20px;" do

        # Whitepages API
        div class: "api-card", style: "background: white; padding: 25px; border-radius: 12px; border: 2px solid #{credentials.whitepages_api_key.present? ? '#28a745' : '#e9ecef'}; box-shadow: 0 2px 8px rgba(0,0,0,0.1);" do
          div style: "display: flex; justify-content: space-between; align-items: start; margin-bottom: 15px;" do
            div do
              h3 style: "margin: 0 0 5px 0; color: #333; font-size: 20px;" do
                "📍 Whitepages Pro"
              end
              para "Residential address lookup", style: "margin: 0; color: #6c757d; font-size: 14px;"
            end

            if credentials.whitepages_api_key.present?
              status_tag "CONFIGURED", class: "ok", style: "font-size: 12px;"
            else
              status_tag "OPTIONAL", class: "default", style: "font-size: 12px;"
            end
          end

          if credentials.whitepages_api_key.present?
            div style: "background: #f8f9fa; padding: 12px; border-radius: 6px; margin-bottom: 12px; font-family: monospace; font-size: 12px;" do
              "Key: ***#{credentials.whitepages_api_key[-4..]}"
            end

            div style: "margin-bottom: 12px;" do
              para "Provides:", style: "margin: 0 0 8px 0; font-weight: bold; font-size: 13px;"
              ul style: "margin: 0; padding-left: 20px; font-size: 13px;" do
                li "Consumer addresses (US)"
                li "Address verification"
                li "Location data"
              end
            end

            if credentials.enable_address_enrichment
              div style: "padding: 10px; background: #d4edda; border-left: 4px solid #28a745; border-radius: 4px; margin-bottom: 12px;" do
                strong "✅ Address Enrichment Active", style: "color: #155724;"
                para "#{Contact.address_enriched.count} addresses found", style: "margin: 5px 0 0 0; font-size: 12px; color: #155724;"
              end
            else
              div style: "padding: 10px; background: #fff3cd; border-left: 4px solid #ffc107; border-radius: 4px; margin-bottom: 12px;" do
                "⚠️ Enable address enrichment to use this API"
              end
            end
          else
            div style: "padding: 15px; background: #f8f9fa; border-left: 4px solid #6c757d; border-radius: 4px; margin-bottom: 12px;" do
              "ℹ️ Optional: Find consumer addresses"
            end
          end

          link_to "⚙️ Configure", edit_admin_twilio_credential_path(credentials, anchor: 'address_enrichment'),
                  class: "button",
                  style: "width: 100%; text-align: center;"
        end

        # TrueCaller API
        div class: "api-card", style: "background: white; padding: 25px; border-radius: 12px; border: 2px solid #{credentials.truecaller_api_key.present? ? '#28a745' : '#e9ecef'}; box-shadow: 0 2px 8px rgba(0,0,0,0.1);" do
          div style: "display: flex; justify-content: space-between; align-items: start; margin-bottom: 15px;" do
            div do
              h3 style: "margin: 0 0 5px 0; color: #333; font-size: 20px;" do
                "📱 TrueCaller"
              end
              para "Alternative address source", style: "margin: 0; color: #6c757d; font-size: 14px;"
            end

            if credentials.truecaller_api_key.present?
              status_tag "CONFIGURED", class: "ok", style: "font-size: 12px;"
            else
              status_tag "OPTIONAL", class: "default", style: "font-size: 12px;"
            end
          end

          if credentials.truecaller_api_key.present?
            div style: "background: #f8f9fa; padding: 12px; border-radius: 6px; margin-bottom: 12px; font-family: monospace; font-size: 12px;" do
              "Key: ***#{credentials.truecaller_api_key[-4..]}"
            end

            div style: "margin-bottom: 12px;" do
              para "Provides:", style: "margin: 0 0 8px 0; font-weight: bold; font-size: 13px;"
              ul style: "margin: 0; padding-left: 20px; font-size: 13px;" do
                li "Mobile number lookup"
                li "Address information"
                li "Identity verification"
              end
            end
          else
            div style: "padding: 15px; background: #f8f9fa; border-left: 4px solid #6c757d; border-radius: 4px; margin-bottom: 12px;" do
              "ℹ️ Optional: Fallback address source"
            end
          end

          link_to "⚙️ Configure", edit_admin_twilio_credential_path(credentials, anchor: 'address_enrichment'),
                  class: "button",
                  style: "width: 100%; text-align: center;"
        end

        # Verizon Coverage
        div class: "api-card", style: "background: white; padding: 25px; border-radius: 12px; border: 2px solid #{credentials.enable_verizon_coverage_check ? '#28a745' : '#e9ecef'}; box-shadow: 0 2px 8px rgba(0,0,0,0.1);" do
          div style: "display: flex; justify-content: space-between; align-items: start; margin-bottom: 15px;" do
            div do
              h3 style: "margin: 0 0 5px 0; color: #333; font-size: 20px;" do
                "📡 Verizon Coverage"
              end
              para "5G/LTE Home Internet check", style: "margin: 0; color: #6c757d; font-size: 14px;"
            end

            if credentials.enable_verizon_coverage_check
              status_tag "ENABLED", class: "ok", style: "font-size: 12px;"
            else
              status_tag "DISABLED", class: "default", style: "font-size: 12px;"
            end
          end

          div style: "background: #e7f3ff; padding: 12px; border-radius: 6px; margin-bottom: 12px; font-size: 12px;" do
            "ℹ️ No API key required - uses Verizon's public checker"
          end

          div style: "margin-bottom: 12px;" do
            para "Checks:", style: "margin: 0 0 8px 0; font-weight: bold; font-size: 13px;"
            ul style: "margin: 0; padding-left: 20px; font-size: 13px;" do
              li "5G Home Internet availability"
              li "LTE Home Internet availability"
              li "Fios availability"
              li "Estimated speeds"
            end
          end

          if credentials.enable_verizon_coverage_check
            div style: "padding: 10px; background: #d4edda; border-left: 4px solid #28a745; border-radius: 4px; margin-bottom: 12px;" do
              strong "✅ Coverage Check Active", style: "color: #155724;"
              checked_count = Contact.verizon_coverage_checked.count
              available_count = Contact.verizon_home_internet_available.count
              para "#{checked_count} checked, #{available_count} available", style: "margin: 5px 0 0 0; font-size: 12px; color: #155724;"
            end
          else
            div style: "padding: 10px; background: #f8f9fa; border-left: 4px solid #6c757d; border-radius: 4px; margin-bottom: 12px;" do
              "Enable to check Verizon availability for consumers"
            end
          end

          link_to "⚙️ Configure", edit_admin_twilio_credential_path(credentials, anchor: 'address_enrichment'),
                  class: "button",
                  style: "width: 100%; text-align: center;"
        end
      end
    end

    # ========================================
    # BUSINESS DIRECTORY APIS
    # ========================================
    panel "📍 Business Directory APIs", class: "api-section" do
      div style: "display: grid; grid-template-columns: repeat(auto-fit, minmax(350px, 1fr)); gap: 20px;" do

        # Google Places API
        div class: "api-card", style: "background: white; padding: 25px; border-radius: 12px; border: 2px solid #{credentials.google_places_api_key.present? ? '#28a745' : '#e9ecef'}; box-shadow: 0 2px 8px rgba(0,0,0,0.1);" do
          div style: "display: flex; justify-content: space-between; align-items: start; margin-bottom: 15px;" do
            div do
              h3 style: "margin: 0 0 5px 0; color: #333; font-size: 20px;" do
                "🗺️ Google Places"
              end
              para "Business directory lookup", style: "margin: 0; color: #6c757d; font-size: 14px;"
            end

            if credentials.google_places_api_key.present?
              status_tag "CONFIGURED", class: "ok", style: "font-size: 12px;"
            else
              status_tag "OPTIONAL", class: "default", style: "font-size: 12px;"
            end
          end

          if credentials.google_places_api_key.present?
            div style: "background: #f8f9fa; padding: 12px; border-radius: 6px; margin-bottom: 12px; font-family: monospace; font-size: 12px;" do
              "Key: AIza***#{credentials.google_places_api_key[-4..]}"
            end

            div style: "margin-bottom: 12px;" do
              para "Provides:", style: "margin: 0 0 8px 0; font-weight: bold; font-size: 13px;"
              ul style: "margin: 0; padding-left: 20px; font-size: 13px;" do
                li "Zipcode business search"
                li "Business name & address"
                li "Phone numbers & websites"
                li "Comprehensive coverage"
              end
            end

            if credentials.enable_zipcode_lookup
              div style: "padding: 10px; background: #d4edda; border-left: 4px solid #28a745; border-radius: 4px; margin-bottom: 12px;" do
                strong "✅ Zipcode Lookup Active", style: "color: #155724;"
                zipcode_count = ZipcodeLookup.count
                para "#{zipcode_count} zipcode searches performed", style: "margin: 5px 0 0 0; font-size: 12px; color: #155724;"
              end
            else
              div style: "padding: 10px; background: #fff3cd; border-left: 4px solid #ffc107; border-radius: 4px; margin-bottom: 12px;" do
                "⚠️ Enable zipcode lookup to use this API"
              end
            end
          else
            div style: "padding: 15px; background: #f8f9fa; border-left: 4px solid #6c757d; border-radius: 4px; margin-bottom: 12px;" do
              "ℹ️ Optional: Find businesses by zipcode"
            end
          end

          link_to "⚙️ Configure", edit_admin_twilio_credential_path(credentials, anchor: 'zipcode_lookup'),
                  class: "button",
                  style: "width: 100%; text-align: center;"
        end

        # Yelp API
        div class: "api-card", style: "background: white; padding: 25px; border-radius: 12px; border: 2px solid #{credentials.yelp_api_key.present? ? '#28a745' : '#e9ecef'}; box-shadow: 0 2px 8px rgba(0,0,0,0.1);" do
          div style: "display: flex; justify-content: space-between; align-items: start; margin-bottom: 15px;" do
            div do
              h3 style: "margin: 0 0 5px 0; color: #333; font-size: 20px;" do
                "⭐ Yelp Fusion"
              end
              para "Alternative business directory", style: "margin: 0; color: #6c757d; font-size: 14px;"
            end

            if credentials.yelp_api_key.present?
              status_tag "CONFIGURED", class: "ok", style: "font-size: 12px;"
            else
              status_tag "OPTIONAL", class: "default", style: "font-size: 12px;"
            end
          end

          if credentials.yelp_api_key.present?
            div style: "background: #f8f9fa; padding: 12px; border-radius: 6px; margin-bottom: 12px; font-family: monospace; font-size: 12px;" do
              "Key: ***#{credentials.yelp_api_key[-4..]}"
            end

            div style: "margin-bottom: 12px;" do
              para "Provides:", style: "margin: 0 0 8px 0; font-weight: bold; font-size: 13px;"
              ul style: "margin: 0; padding-left: 20px; font-size: 13px;" do
                li "Business search by location"
                li "Ratings & reviews"
                li "Contact information"
                li "Fallback data source"
              end
            end
          else
            div style: "padding: 15px; background: #f8f9fa; border-left: 4px solid #6c757d; border-radius: 4px; margin-bottom: 12px;" do
              "ℹ️ Optional: Fallback business directory"
            end
          end

          link_to "⚙️ Configure", edit_admin_twilio_credential_path(credentials, anchor: 'zipcode_lookup'),
                  class: "button",
                  style: "width: 100%; text-align: center;"
        end
      end
    end

    # ========================================
    # AI & AUTOMATION APIS
    # ========================================
    panel "🤖 AI & Automation APIs", class: "api-section" do
      div style: "display: grid; grid-template-columns: repeat(auto-fit, minmax(350px, 1fr)); gap: 20px;" do

        # OpenAI API
        div class: "api-card", style: "background: white; padding: 25px; border-radius: 12px; border: 2px solid #{credentials.openai_api_key.present? ? '#28a745' : '#e9ecef'}; box-shadow: 0 2px 8px rgba(0,0,0,0.1);" do
          div style: "display: flex; justify-content: space-between; align-items: start; margin-bottom: 15px;" do
            div do
              h3 style: "margin: 0 0 5px 0; color: #333; font-size: 20px;" do
                "🧠 OpenAI GPT"
              end
              para "AI-powered intelligence", style: "margin: 0; color: #6c757d; font-size: 14px;"
            end

            if credentials.openai_api_key.present?
              status_tag "CONFIGURED", class: "ok", style: "font-size: 12px;"
            else
              status_tag "OPTIONAL", class: "default", style: "font-size: 12px;"
            end
          end

          if credentials.openai_api_key.present?
            div style: "background: #f8f9fa; padding: 12px; border-radius: 6px; margin-bottom: 12px; font-family: monospace; font-size: 12px;" do
              "Key: sk-***#{credentials.openai_api_key[-4..]}"
              para "Model: #{credentials.ai_model || 'gpt-4o-mini'}", style: "margin: 5px 0 0 0;"
            end

            div style: "margin-bottom: 12px;" do
              para "Features:", style: "margin: 0 0 8px 0; font-weight: bold; font-size: 13px;"
              ul style: "margin: 0; padding-left: 20px; font-size: 13px;" do
                li "Natural language search"
                li "Sales intelligence"
                li "Outreach generation"
                li "Data insights"
              end
            end

            if credentials.enable_ai_features
              div style: "padding: 10px; background: #d4edda; border-left: 4px solid #28a745; border-radius: 4px; margin-bottom: 12px;" do
                strong "✅ AI Features Active", style: "color: #155724;"
                para "Ready to use AI Assistant", style: "margin: 5px 0 0 0; font-size: 12px; color: #155724;"
              end

              link_to "🤖 Open AI Assistant →", admin_ai_assistant_path,
                      class: "button primary",
                      style: "width: 100%; text-align: center; margin-bottom: 10px;"
            else
              div style: "padding: 10px; background: #fff3cd; border-left: 4px solid #ffc107; border-radius: 4px; margin-bottom: 12px;" do
                "⚠️ Enable AI features to unlock capabilities"
              end
            end
          else
            div style: "padding: 15px; background: #f8f9fa; border-left: 4px solid #6c757d; border-radius: 4px; margin-bottom: 12px;" do
              "ℹ️ Optional: Enables AI-powered features"
            end
          end

          link_to "⚙️ Configure", edit_admin_twilio_credential_path(credentials, anchor: 'ai_assistant'),
                  class: "button",
                  style: "width: 100%; text-align: center;"
        end
      end
    end

    # ========================================
    # Quick Actions
    # ========================================
    panel "⚡ Quick Actions" do
      div style: "display: flex; gap: 15px; flex-wrap: wrap;" do
        link_to "📝 Edit All Settings", edit_admin_twilio_credential_path(credentials),
                class: "button primary",
                style: "flex: 1; min-width: 200px; text-align: center; padding: 15px;"

        link_to "🔄 Test All Connections", "#",
                class: "button",
                style: "flex: 1; min-width: 200px; text-align: center; padding: 15px;",
                onclick: "alert('Connection test feature coming soon!'); return false;"

        link_to "📊 View Dashboard", admin_dashboard_path,
                class: "button",
                style: "flex: 1; min-width: 200px; text-align: center; padding: 15px;"

        link_to "📞 Manage Contacts", admin_contacts_path,
                class: "button",
                style: "flex: 1; min-width: 200px; text-align: center; padding: 15px;"
      end
    end
  end
end
