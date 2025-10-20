ActiveAdmin.register TwilioCredential do
  menu priority: 5, label: "Twilio Settings"
  
  # ========================================
  # Configuration
  # ========================================
  config.filters = false # No need for filters with single record
  
  # ========================================
  # Index View
  # ========================================
  index do
    column "Account SID" do |cred|
      # Partially mask for security
      if cred.account_sid.present?
        "#{cred.account_sid[0..5]}***#{cred.account_sid[-4..]}"
      else
        span "Not set", style: "color: #dc3545;"
      end
    end
    
    column "Auth Token" do |cred|
      if cred.auth_token.present?
        status_tag "Configured", class: "completed"
      else
        status_tag "Not Configured", class: "failed"
      end
    end
    
    column "Last Updated" do |cred|
      cred.updated_at.strftime("%b %d, %Y %H:%M")
    end
    
    column "Status" do |cred|
      # Test credentials
      begin
        client = Twilio::REST::Client.new(cred.account_sid, cred.auth_token)
        # Make a simple API call to verify credentials
        client.api.accounts(cred.account_sid).fetch
        status_tag "Valid", class: "completed"
      rescue => e
        status_tag "Invalid", class: "failed", title: e.message
      end
    end
    
    actions defaults: true
  end
  
  # ========================================
  # Form (Edit/New)
  # ========================================
  form do |f|
    f.semantic_errors
    
    # Instructions Panel
    panel "📝 Setup Instructions" do
      div style: "background: #f8f9fa; padding: 20px; border-radius: 8px; margin-bottom: 20px;" do
        h3 "How to Get Your Twilio Credentials", style: "margin-top: 0;"
        
        ol do
          li do
            span "Log in to your "
            link_to "Twilio Console", "https://console.twilio.com", target: "_blank", style: "font-weight: bold;"
          end
          li "Navigate to Account → General Settings"
          li "Find your Account SID and Auth Token"
          li "Copy and paste them into the form below"
        end
        
        div style: "margin-top: 15px; padding: 10px; background: #fff3cd; border-left: 4px solid #ffc107; border-radius: 4px;" do
          strong "⚠️ Security Note: "
          span "These credentials grant access to your Twilio account. Keep them secure and never share them publicly."
        end
        
        div style: "margin-top: 15px; padding: 10px; background: #d1ecf1; border-left: 4px solid #0c5460; border-radius: 4px;" do
          strong "💡 Production Tip: "
          span "For production deployments, use environment variables instead: "
          code "TWILIO_ACCOUNT_SID"
          span " and "
          code "TWILIO_AUTH_TOKEN"
        end
      end
    end
    
    f.inputs "Twilio API Credentials" do
      f.input :account_sid,
              label: "Account SID",
              placeholder: "ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
              hint: "Your Twilio Account SID (starts with 'AC' followed by 32 characters)",
              input_html: { 
                style: "font-family: monospace; font-size: 14px;",
                autocomplete: "off"
              }
      
      f.input :auth_token,
              label: "Auth Token",
              placeholder: "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
              hint: "Your Twilio Auth Token (32 alphanumeric characters)",
              input_html: { 
                type: "password",
                style: "font-family: monospace; font-size: 14px;",
                autocomplete: "new-password"
              }
    end

    f.inputs "Twilio Lookup API v2 Data Packages", class: "data-packages" do
      div style: "background: #e7f3ff; padding: 15px; border-radius: 8px; margin-bottom: 20px;" do
        h4 "Configure which data packages to fetch with each lookup:", style: "margin-top: 0;"
        para "Each enabled package may incur additional costs. See ", style: "margin: 0;"
        link_to "Twilio Lookup pricing", "https://www.twilio.com/lookup/pricing", target: "_blank"
        span " for details."
      end

      f.input :enable_line_type_intelligence,
              label: "📡 Line Type Intelligence",
              hint: "Get detailed line type info (mobile, landline, VoIP, etc.) with carrier details. <strong>Worldwide coverage.</strong>",
              input_html: { checked: true }

      f.input :enable_caller_name,
              label: "👤 Caller Name (CNAM)",
              hint: "Get caller name and type information. <strong>US numbers only.</strong>",
              input_html: { checked: true }

      f.input :enable_sms_pumping_risk,
              label: "🛡️ SMS Pumping Fraud Risk",
              hint: "Detect fraud risk with real-time risk scores (0-100). <strong>Essential for fraud prevention.</strong>",
              input_html: { checked: true }

      f.input :enable_sim_swap,
              label: "📱 SIM Swap Detection",
              hint: "Detect recent SIM changes for security verification. <strong>Limited coverage - requires carrier approval.</strong>",
              input_html: { checked: false }

      f.input :enable_reassigned_number,
              label: "♻️ Reassigned Number Detection",
              hint: "Check if number has been reassigned to a new user. <strong>US only - requires approval.</strong>",
              input_html: { checked: false }
    end

    f.inputs "Notes & Configuration" do
      f.input :notes,
              label: "Configuration Notes",
              hint: "Optional: Add notes about your Twilio configuration, rate limits, or special settings",
              input_html: { rows: 4 }
    end

    f.inputs "🏢 Business Intelligence Enrichment", class: "business-enrichment" do
      div style: "background: #e7f3ff; padding: 15px; border-radius: 8px; margin-bottom: 20px;" do
        h4 "Enrich business contacts with company data:", style: "margin-top: 0;"
        para "Automatically fetch business name, employee count, revenue, industry, and more.", style: "margin: 0;"
      end

      f.input :enable_business_enrichment,
              label: "Enable Business Enrichment",
              hint: "Automatically enrich contacts identified as businesses with company intelligence data"

      f.input :auto_enrich_businesses,
              label: "Auto-Enrich After Lookup",
              hint: "Automatically queue business enrichment after successful Twilio lookup"

      f.input :enrichment_confidence_threshold,
              label: "Confidence Threshold (0-100)",
              hint: "Only save business data with confidence score above this threshold",
              input_html: { min: 0, max: 100 }

      div style: "margin-top: 20px; padding: 15px; background: #fff3cd; border-left: 4px solid #ffc107; border-radius: 4px;" do
        strong "🔑 Business Enrichment API Keys"
        para "Configure API keys for business data providers below:", style: "margin: 5px 0;"
      end

      f.input :clearbit_api_key,
              label: "Clearbit API Key",
              hint: "Premium business intelligence (recommended). Get your key at https://clearbit.com",
              input_html: { 
                type: "password",
                style: "font-family: monospace; font-size: 14px;",
                autocomplete: "new-password",
                placeholder: "sk_..."
              }

      f.input :numverify_api_key,
              label: "NumVerify API Key",
              hint: "Basic phone intelligence with business detection. Get free key at https://numverify.com",
              input_html: { 
                type: "password",
                style: "font-family: monospace; font-size: 14px;",
                autocomplete: "new-password"
              }

      div style: "margin-top: 15px; padding: 10px; background: #d1ecf1; border-left: 4px solid #0c5460; border-radius: 4px;" do
        strong "💡 Provider Priority: "
        span "Clearbit → NumVerify → Twilio CNAM (fallback)"
      end
    end

    f.inputs "✉️ Email Enrichment & Verification", class: "email-enrichment" do
      div style: "background: #e7f3ff; padding: 15px; border-radius: 8px; margin-bottom: 20px;" do
        h4 "Find and verify email addresses for contacts:", style: "margin-top: 0;"
        para "Automatically discover professional email addresses and verify their deliverability.", style: "margin: 0;"
      end

      f.input :enable_email_enrichment,
              label: "Enable Email Enrichment",
              hint: "Automatically find and verify email addresses for contacts after business enrichment"

      div style: "margin-top: 20px; padding: 15px; background: #fff3cd; border-left: 4px solid #ffc107; border-radius: 4px;" do
        strong "🔑 Email Enrichment API Keys"
        para "Configure API keys for email finding and verification providers:", style: "margin: 5px 0;"
      end

      f.input :hunter_api_key,
              label: "Hunter.io API Key",
              hint: "Email finding and verification service. Get your key at https://hunter.io",
              input_html: { 
                type: "password",
                style: "font-family: monospace; font-size: 14px;",
                autocomplete: "new-password"
              }

      f.input :zerobounce_api_key,
              label: "ZeroBounce API Key",
              hint: "Email verification service. Get your key at https://www.zerobounce.net",
              input_html: { 
                type: "password",
                style: "font-family: monospace; font-size: 14px;",
                autocomplete: "new-password"
              }

      div style: "margin-top: 15px; padding: 10px; background: #d1ecf1; border-left: 4px solid #0c5460; border-radius: 4px;" do
        strong "💡 Email Discovery: "
        span "Hunter.io (finding) → ZeroBounce (verification) → Clearbit Email (fallback)"
      end
    end

    f.inputs "🔍 Duplicate Detection & Merging", class: "duplicate-detection" do
      div style: "background: #e7f3ff; padding: 15px; border-radius: 8px; margin-bottom: 20px;" do
        h4 "Identify and merge duplicate contacts:", style: "margin-top: 0;"
        para "Uses fuzzy matching to find duplicates by phone, email, and business name.", style: "margin: 0;"
      end

      f.input :enable_duplicate_detection,
              label: "Enable Duplicate Detection",
              hint: "Automatically check for duplicate contacts after enrichment"

      f.input :duplicate_confidence_threshold,
              label: "Confidence Threshold (0-100)",
              hint: "Show duplicates with confidence score above this threshold (recommended: 70-80)",
              input_html: { min: 0, max: 100, value: 75 }

      f.input :auto_merge_duplicates,
              label: "Auto-Merge High Confidence Duplicates",
              hint: "Automatically merge contacts with 95%+ confidence match (use with caution)",
              input_html: { checked: false }

      div style: "margin-top: 15px; padding: 15px; background: #fff3cd; border-left: 4px solid #ffc107; border-radius: 4px;" do
        strong "⚠️ Auto-Merge Warning: "
        para "Auto-merging is permanent. Review duplicates manually before enabling this feature.", style: "margin: 5px 0 0 0;"
      end
    end

    f.inputs "🤖 AI Assistant (GPT Integration)", class: "ai-assistant" do
      div style: "background: #e7f3ff; padding: 15px; border-radius: 8px; margin-bottom: 20px;" do
        h4 "Enable AI-powered features:", style: "margin-top: 0;"
        para "Natural language search, sales intelligence, and automated outreach generation.", style: "margin: 0;"
      end

      f.input :enable_ai_features,
              label: "Enable AI Features",
              hint: "Unlock AI assistant, natural language search, and intelligent recommendations"

      div style: "margin-top: 20px; padding: 15px; background: #fff3cd; border-left: 4px solid #ffc107; border-radius: 4px;" do
        strong "🔑 OpenAI API Configuration"
        para "Configure your OpenAI API key to enable AI features:", style: "margin: 5px 0;"
      end

      f.input :openai_api_key,
              label: "OpenAI API Key",
              hint: "Get your API key at https://platform.openai.com/api-keys",
              input_html: { 
                type: "password",
                style: "font-family: monospace; font-size: 14px;",
                autocomplete: "new-password",
                placeholder: "sk-..."
              }

      f.input :ai_model,
              label: "AI Model",
              as: :select,
              collection: [
                ['GPT-4o (Recommended - Fast & Smart)', 'gpt-4o'],
                ['GPT-4o-mini (Budget-Friendly)', 'gpt-4o-mini'],
                ['GPT-4 Turbo (Most Capable)', 'gpt-4-turbo'],
                ['GPT-3.5 Turbo (Fastest)', 'gpt-3.5-turbo']
              ],
              hint: "Choose the AI model for intelligence features (gpt-4o-mini recommended for sales use)",
              input_html: { selected: 'gpt-4o-mini' }

      f.input :ai_max_tokens,
              label: "Max Response Tokens",
              hint: "Maximum tokens for AI responses (500-2000 recommended)",
              input_html: { min: 100, max: 4000, value: 1000 }

      div style: "margin-top: 15px; padding: 10px; background: #d1ecf1; border-left: 4px solid #0c5460; border-radius: 4px;" do
        strong "💡 AI Features: "
        ul style: "margin: 10px 0 0 20px;" do
          li "Natural language contact search"
          li "Sales intelligence and recommendations"
          li "Automated outreach message generation"
          li "Data insights and trend analysis"
        end
      end
    end

    f.inputs "📍 Business Directory / Zipcode Lookup", class: "business-directory" do
      div style: "background: #e7f3ff; padding: 15px; border-radius: 8px; margin-bottom: 20px;" do
        h4 "Search for businesses by zipcode:", style: "margin-top: 0;"
        para "Automatically find and import businesses from specific geographic areas.", style: "margin: 0;"
      end

      f.input :enable_zipcode_lookup,
              label: "Enable Zipcode Business Lookup",
              hint: "Allow searching and importing businesses by zipcode from business directories"

      f.input :results_per_zipcode,
              label: "Results Per Zipcode",
              hint: "Maximum number of businesses to fetch per zipcode (1-50 recommended)",
              input_html: { min: 1, max: 100, value: 20 }

      f.input :auto_enrich_zipcode_results,
              label: "Auto-Enrich Imported Businesses",
              hint: "Automatically run phone lookup and email enrichment on newly imported businesses",
              input_html: { checked: true }

      div style: "margin-top: 20px; padding: 15px; background: #fff3cd; border-left: 4px solid #ffc107; border-radius: 4px;" do
        strong "🔑 Business Directory API Keys"
        para "Configure at least one API to enable zipcode lookup:", style: "margin: 5px 0;"
      end

      f.input :google_places_api_key,
              label: "Google Places API Key",
              hint: "Recommended for comprehensive business data. Get your key at https://console.cloud.google.com/apis",
              input_html: { 
                type: "password",
                style: "font-family: monospace; font-size: 14px;",
                autocomplete: "new-password",
                placeholder: "AIza..."
              }

      f.input :yelp_api_key,
              label: "Yelp Fusion API Key",
              hint: "Alternative/fallback source. Get your key at https://www.yelp.com/developers",
              input_html: { 
                type: "password",
                style: "font-family: monospace; font-size: 14px;",
                autocomplete: "new-password"
              }

      div style: "margin-top: 15px; padding: 10px; background: #d1ecf1; border-left: 4px solid #0c5460; border-radius: 4px;" do
        strong "💡 Provider Priority: "
        span "Google Places (first) → Yelp (fallback)"
        para " ", style: "margin: 10px 0 0 0;"
        strong "Features:"
        ul style: "margin: 5px 0 0 20px;" do
          li "Single or bulk zipcode lookup"
          li "Automatic duplicate prevention"
          li "Updates existing businesses instead of duplicating"
          li "Imports business name, address, phone, website"
        end
      end
    end
    
    f.actions do
      f.action :submit, label: "Save Credentials", button_html: { class: "button primary" }
      f.action :cancel, label: "Cancel"
    end
  end
  
  # ========================================
  # Show Page
  # ========================================
  show do
    panel "Twilio API Credentials" do
      attributes_table_for twilio_credential do
        row "Account SID" do |cred|
          div do
            # Show partially masked
            span "#{cred.account_sid[0..5]}***#{cred.account_sid[-4..]}", 
                 style: "font-family: monospace; font-size: 14px;"
            span " (masked for security)", style: "color: #6c757d; font-size: 12px; margin-left: 10px;"
          end
        end
        
        row "Auth Token" do
          div do
            span "••••••••••••••••••••••••••••••••", style: "font-family: monospace;"
            status_tag "Configured", class: "completed", style: "margin-left: 10px;"
          end
        end
        
        row "Created At" do |cred|
          cred.created_at.strftime("%B %d, %Y at %H:%M")
        end
        
        row "Last Updated" do |cred|
          cred.updated_at.strftime("%B %d, %Y at %H:%M")
        end
      end
    end

    panel "🔧 Lookup API v2 Data Packages Configuration" do
      attributes_table_for twilio_credential do
        row "Line Type Intelligence" do |cred|
          if cred.enable_line_type_intelligence
            status_tag "Enabled", class: "ok"
          else
            status_tag "Disabled", class: "error"
          end
        end

        row "Caller Name (CNAM)" do |cred|
          if cred.enable_caller_name
            status_tag "Enabled", class: "ok"
          else
            status_tag "Disabled", class: "error"
          end
        end

        row "SMS Pumping Risk Detection" do |cred|
          if cred.enable_sms_pumping_risk
            status_tag "Enabled", class: "ok"
          else
            status_tag "Disabled", class: "error"
          end
        end

        row "SIM Swap Detection" do |cred|
          if cred.enable_sim_swap
            status_tag "Enabled", class: "warning"
          else
            status_tag "Disabled", class: "default"
          end
        end

        row "Reassigned Number Detection" do |cred|
          if cred.enable_reassigned_number
            status_tag "Enabled", class: "warning"
          else
            status_tag "Disabled", class: "default"
          end
        end

        row "API Fields Parameter" do |cred|
          if cred.data_packages.present?
            code cred.data_packages, style: "background: #f8f9fa; padding: 5px 10px; border-radius: 4px; font-family: monospace;"
          else
            span "No data packages enabled (basic lookup only)", style: "color: #6c757d;"
          end
        end
      end

      div style: "margin-top: 15px; padding: 15px; background: #fff3cd; border-left: 4px solid #ffc107; border-radius: 4px;" do
        strong "💰 Cost Information: "
        para "Each enabled data package incurs additional API costs per lookup. Review Twilio pricing before enabling.", style: "margin: 5px 0 0 0;"
      end
    end

    panel "📝 Configuration Notes" do
      if twilio_credential.notes.present?
        div style: "background: #f8f9fa; padding: 15px; border-radius: 8px; white-space: pre-wrap;" do
          twilio_credential.notes
        end
      else
        para "No configuration notes.", style: "color: #6c757d;"
      end
    end

    panel "🏢 Business Intelligence Enrichment" do
      attributes_table_for twilio_credential do
        row "Business Enrichment" do |cred|
          if cred.enable_business_enrichment
            status_tag "Enabled", class: "ok"
          else
            status_tag "Disabled", class: "error"
          end
        end

        row "Auto-Enrich After Lookup" do |cred|
          if cred.auto_enrich_businesses
            status_tag "Yes", class: "ok"
          else
            status_tag "No", class: "default"
          end
        end

        row "Confidence Threshold" do |cred|
          "#{cred.enrichment_confidence_threshold}/100"
        end

        row "Clearbit API" do |cred|
          if cred.clearbit_api_key.present?
            status_tag "Configured", class: "ok"
          else
            span "Not configured", style: "color: #6c757d;"
          end
        end

        row "NumVerify API" do |cred|
          if cred.numverify_api_key.present?
            status_tag "Configured", class: "ok"
          else
            span "Not configured", style: "color: #6c757d;"
          end
        end
      end

      div style: "margin-top: 15px; padding: 15px; background: #e7f3ff; border-left: 4px solid #0c5460; border-radius: 4px;" do
        strong "📊 Business Data Collected:"
        ul style: "margin: 10px 0 0 20px;" do
          li "Company name, legal name, and description"
          li "Employee count and revenue estimates"
          li "Industry, category, and business type"
          li "Location (address, city, state, country)"
          li "Contact info (website, email domain, social media)"
          li "Technology stack and company tags"
        end
      end
    end

    panel "✉️ Email Enrichment & Verification" do
      attributes_table_for twilio_credential do
        row "Email Enrichment" do |cred|
          if cred.enable_email_enrichment
            status_tag "Enabled", class: "ok"
          else
            status_tag "Disabled", class: "error"
          end
        end

        row "Hunter.io API" do |cred|
          if cred.hunter_api_key.present?
            status_tag "Configured", class: "ok"
          else
            span "Not configured", style: "color: #6c757d;"
          end
        end

        row "ZeroBounce API" do |cred|
          if cred.zerobounce_api_key.present?
            status_tag "Configured", class: "ok"
          else
            span "Not configured", style: "color: #6c757d;"
          end
        end
      end

      div style: "margin-top: 15px; padding: 15px; background: #e7f3ff; border-left: 4px solid #0c5460; border-radius: 4px;" do
        strong "📧 Email Data Collected:"
        ul style: "margin: 10px 0 0 20px;" do
          li "Primary and additional email addresses"
          li "Email verification status and deliverability score"
          li "Contact person name, title, and department"
          li "Seniority level and role information"
          li "Social media profiles (LinkedIn, Twitter, Facebook)"
        end
      end
    end

    panel "🔍 Duplicate Detection & Merging" do
      attributes_table_for twilio_credential do
        row "Duplicate Detection" do |cred|
          if cred.enable_duplicate_detection
            status_tag "Enabled", class: "ok"
          else
            status_tag "Disabled", class: "error"
          end
        end

        row "Confidence Threshold" do |cred|
          "#{cred.duplicate_confidence_threshold || 75}/100"
        end

        row "Auto-Merge Duplicates" do |cred|
          if cred.auto_merge_duplicates
            div do
              status_tag "Yes", class: "warning"
              span " (95%+ confidence only)", style: "color: #6c757d; margin-left: 10px;"
            end
          else
            status_tag "No", class: "default"
          end
        end
      end

      div style: "margin-top: 15px; padding: 15px; background: #fff3cd; border-left: 4px solid #ffc107; border-radius: 4px;" do
        strong "🎯 Duplicate Matching Strategy:"
        ul style: "margin: 10px 0 0 20px;" do
          li "Phone number exact and fuzzy matching"
          li "Email address comparison"
          li "Business name and location similarity"
          li "Personal name fuzzy matching (Levenshtein distance)"
          li "Fingerprinting for fast duplicate detection"
        end
      end
    end

    panel "🤖 AI Assistant Configuration" do
      attributes_table_for twilio_credential do
        row "AI Features" do |cred|
          if cred.enable_ai_features
            status_tag "Enabled", class: "ok"
          else
            status_tag "Disabled", class: "error"
          end
        end

        row "OpenAI API Key" do |cred|
          if cred.openai_api_key.present?
            div do
              span "sk-•••••••••••••••••••••••", style: "font-family: monospace;"
              status_tag "Configured", class: "ok", style: "margin-left: 10px;"
            end
          else
            span "Not configured", style: "color: #6c757d;"
          end
        end

        row "AI Model" do |cred|
          if cred.ai_model.present?
            status_tag cred.ai_model, class: "default"
          else
            "gpt-4o-mini (default)"
          end
        end

        row "Max Response Tokens" do |cred|
          cred.ai_max_tokens || 1000
        end
      end

      div style: "margin-top: 15px; padding: 15px; background: #e7f3ff; border-left: 4px solid #0c5460; border-radius: 4px;" do
        strong "🚀 AI Features Available:"
        ul style: "margin: 10px 0 0 20px;" do
          li "Natural language contact search - Find contacts with plain English queries"
          li "Sales intelligence - Get AI-powered insights about your contacts"
          li "Smart recommendations - Discover trends and opportunities"
          li "Outreach generation - AI-generated personalized messages"
        end
      end

      if twilio_credential.enable_ai_features && twilio_credential.openai_api_key.present?
        div style: "margin-top: 15px; padding: 15px; background: #d4edda; border-left: 4px solid #28a745; border-radius: 4px;" do
          strong "✅ AI Assistant Ready!"
          para "Visit the AI Assistant page to start using natural language search and intelligence features.", style: "margin: 5px 0 0 0;"
          link_to "Go to AI Assistant →", admin_ai_assistant_path, class: "button primary", style: "margin-top: 10px; display: inline-block;"
        end
      end
    end

    panel "📍 Business Directory / Zipcode Lookup" do
      attributes_table_for twilio_credential do
        row "Zipcode Lookup" do |cred|
          if cred.enable_zipcode_lookup
            status_tag "Enabled", class: "ok"
          else
            status_tag "Disabled", class: "error"
          end
        end

        row "Results Per Zipcode" do |cred|
          "#{cred.results_per_zipcode || 20} businesses per zipcode"
        end

        row "Auto-Enrich Results" do |cred|
          if cred.auto_enrich_zipcode_results
            status_tag "Yes", class: "ok"
          else
            status_tag "No", class: "default"
          end
        end

        row "Google Places API" do |cred|
          if cred.google_places_api_key.present?
            div do
              span "AIza•••••••••••••••••••", style: "font-family: monospace;"
              status_tag "Configured", class: "ok", style: "margin-left: 10px;"
            end
          else
            span "Not configured", style: "color: #6c757d;"
          end
        end

        row "Yelp Fusion API" do |cred|
          if cred.yelp_api_key.present?
            div do
              span "•••••••••••••••••••••••", style: "font-family: monospace;"
              status_tag "Configured", class: "ok", style: "margin-left: 10px;"
            end
          else
            span "Not configured", style: "color: #6c757d;"
          end
        end
      end

      div style: "margin-top: 15px; padding: 15px; background: #e7f3ff; border-left: 4px solid #0c5460; border-radius: 4px;" do
        strong "🔍 Zipcode Lookup Features:"
        ul style: "margin: 10px 0 0 20px;" do
          li "Search for businesses in specific zipcodes"
          li "Single or bulk zipcode processing"
          li "Automatic duplicate prevention"
          li "Updates existing businesses instead of creating duplicates"
          li "Auto-enrichment with phone validation and email finding"
        end
      end

      if twilio_credential.enable_zipcode_lookup && (twilio_credential.google_places_api_key.present? || twilio_credential.yelp_api_key.present?)
        div style: "margin-top: 15px; padding: 15px; background: #d4edda; border-left: 4px solid #28a745; border-radius: 4px;" do
          strong "✅ Business Lookup Ready!"
          para "Visit the Business Lookup page to start searching for businesses by zipcode.", style: "margin: 5px 0 0 0;"
          link_to "Go to Business Lookup →", admin_business_lookup_path, class: "button primary", style: "margin-top: 10px; display: inline-block;"
        end
      end
    end
    
    panel "Connection Test" do
      div style: "padding: 15px; background: #f8f9fa; border-radius: 8px;" do
        begin
          client = Twilio::REST::Client.new(twilio_credential.account_sid, twilio_credential.auth_token)
          account = client.api.accounts(twilio_credential.account_sid).fetch
          
          div style: "color: #11998e; font-weight: bold; font-size: 16px; margin-bottom: 10px;" do
            "✅ Credentials are valid and working!"
          end
          
          attributes_table_for account do
            row("Account Name") { account.friendly_name }
            row("Account Status") { status_tag account.status }
            row("Account Type") { account.type }
          end
          
        rescue Twilio::REST::RestError => e
          div style: "color: #dc3545; font-weight: bold; font-size: 16px; margin-bottom: 10px;" do
            "❌ Credential Validation Failed"
          end
          
          div style: "background: white; padding: 15px; border-left: 4px solid #dc3545; border-radius: 4px; margin-top: 10px;" do
            strong "Error: "
            span e.message
          end
          
          div style: "margin-top: 15px; padding: 10px; background: #fff3cd; border-radius: 4px;" do
            strong "Troubleshooting:"
            ul style: "margin: 10px 0 0 20px;" do
              li "Verify your Account SID and Auth Token are correct"
              li "Check that your Twilio account is active"
              li "Ensure you have API access enabled"
            end
          end
        rescue => e
          div style: "color: #dc3545;" do
            strong "Connection Error: "
            span e.message
          end
        end
      end
    end
    
    panel "Usage Information" do
      div style: "background: #e7f3ff; padding: 15px; border-radius: 8px;" do
        h4 "How These Credentials Are Used", style: "margin-top: 0;"
        
        ul do
          li "Background jobs use these credentials to call the Twilio Lookup API"
          li "Credentials are cached for 1 hour to reduce database queries"
          li "Only one set of credentials can be active at a time"
          li "Updating credentials will clear the cache and use new values immediately"
        end
        
        div style: "margin-top: 15px; padding: 10px; background: white; border-radius: 4px;" do
          strong "Security Recommendations:"
          ul style: "margin: 10px 0 0 20px;" do
            li "Rotate credentials regularly"
            li "Use environment variables in production"
            li "Monitor Twilio console for unusual activity"
            li "Never commit credentials to version control"
          end
        end
      end
    end
    
    active_admin_comments
  end
  
  # ========================================
  # Custom Actions
  # ========================================
  action_item :test_credentials, only: :show do
    link_to "🔍 Test Connection", test_admin_twilio_credential_path(twilio_credential), 
            class: "button"
  end
  
  member_action :test, method: :get do
    begin
      client = Twilio::REST::Client.new(resource.account_sid, resource.auth_token)
      account = client.api.accounts(resource.account_sid).fetch
      
      redirect_to resource_path, notice: "✅ Credentials are valid! Account: #{account.friendly_name}"
    rescue Twilio::REST::RestError => e
      redirect_to resource_path, alert: "❌ Credential test failed: #{e.message}"
    rescue => e
      redirect_to resource_path, alert: "❌ Connection error: #{e.message}"
    end
  end
  
  # ========================================
  # Controller Customization
  # ========================================
  controller do
    def create
      # Enforce singleton pattern
      if TwilioCredential.any?
        redirect_to edit_admin_twilio_credential_path(TwilioCredential.first),
                    alert: "Credentials already exist. Please update them instead."
        return
      end
      
      super
    end
    
    def update
      # Clear cache after update
      Rails.cache.delete('twilio_credentials')
      super
    end
  end
  
  # ========================================
  # Permissions
  # ========================================
  permit_params :account_sid, :auth_token, :enable_line_type_intelligence,
                :enable_caller_name, :enable_sms_pumping_risk, :enable_sim_swap,
                :enable_reassigned_number, :notes, :enable_business_enrichment,
                :auto_enrich_businesses, :enrichment_confidence_threshold,
                :clearbit_api_key, :numverify_api_key,
                # Email enrichment
                :enable_email_enrichment, :hunter_api_key, :zerobounce_api_key,
                # Duplicate detection
                :enable_duplicate_detection, :duplicate_confidence_threshold, :auto_merge_duplicates,
                # AI configuration
                :enable_ai_features, :openai_api_key, :ai_model, :ai_max_tokens,
                # Business directory / zipcode lookup
                :enable_zipcode_lookup, :google_places_api_key, :yelp_api_key,
                :results_per_zipcode, :auto_enrich_zipcode_results
end
