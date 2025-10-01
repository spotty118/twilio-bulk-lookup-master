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
  permit_params :account_sid, :auth_token
end
