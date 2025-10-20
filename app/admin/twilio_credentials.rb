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
                :enable_reassigned_number, :notes
end
