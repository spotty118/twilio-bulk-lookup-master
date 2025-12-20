ActiveAdmin.register TwilioCredential do
  menu priority: 5, label: 'Twilio Settings'

  # ========================================
  # Configuration
  # ========================================
  config.filters = false # No need for filters with single record

  # ========================================
  # Index View
  # ========================================
  index do
    column 'Account SID' do |cred|
      # Partially mask for security
      if cred.account_sid.present?
        "#{cred.account_sid[0..5]}***#{cred.account_sid[-4..]}"
      else
        span 'Not set', style: 'color: #dc3545;'
      end
    end

    column 'Auth Token' do |cred|
      if cred.auth_token.present?
        status_tag 'Configured', class: 'completed'
      else
        status_tag 'Not Configured', class: 'failed'
      end
    end

    column 'Last Updated' do |cred|
      cred.updated_at.strftime('%b %d, %Y %H:%M')
    end

    column 'Status' do |cred|
      # Check cached validation status instead of making blocking API call
      # Use Rails cache to avoid hitting Twilio API on every page load
      cache_key = "twilio_cred_valid_#{cred.id}_#{cred.updated_at.to_i}"
      is_valid = Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
        client = Twilio::REST::Client.new(cred.account_sid, cred.auth_token)
        client.api.accounts(cred.account_sid).fetch
        true
      rescue StandardError
        false
      end

      if is_valid
        status_tag 'Valid', class: 'completed'
      else
        status_tag 'Invalid', class: 'failed', title: 'Click to revalidate'
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
    panel '📝 Setup Instructions' do
      div style: 'background: #f8f9fa; padding: 20px; border-radius: 8px; margin-bottom: 20px;' do
        h3 'How to Get Your Twilio Credentials', style: 'margin-top: 0;'

        ol do
          li do
            span 'Log in to your '
            link_to 'Twilio Console', 'https://console.twilio.com', target: '_blank', style: 'font-weight: bold;'
          end
          li 'Navigate to Account → General Settings'
          li 'Find your Account SID and Auth Token'
          li 'Copy and paste them into the form below'
        end

        div style: 'margin-top: 15px; padding: 10px; background: #fff3cd; border-left: 4px solid #ffc107; border-radius: 4px;' do
          strong '⚠️ Security Note: '
          span 'These credentials grant access to your Twilio account. Keep them secure and never share them publicly.'
        end

        div style: 'margin-top: 15px; padding: 10px; background: #d1ecf1; border-left: 4px solid #0c5460; border-radius: 4px;' do
          strong '💡 Production Tip: '
          span 'For production deployments, use environment variables instead: '
          code 'TWILIO_ACCOUNT_SID'
          span ' and '
          code 'TWILIO_AUTH_TOKEN'
        end
      end
    end

    f.inputs 'Twilio API Credentials' do
      f.input :account_sid,
              label: 'Account SID',
              placeholder: 'ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
              hint: "Your Twilio Account SID (starts with 'AC' followed by 32 characters)",
              input_html: {
                style: 'font-family: monospace; font-size: 14px;',
                autocomplete: 'off'
              }

      f.input :auth_token,
              label: 'Auth Token',
              placeholder: 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
              hint: 'Your Twilio Auth Token (32 alphanumeric characters)',
              input_html: {
                type: 'password',
                style: 'font-family: monospace; font-size: 14px;',
                autocomplete: 'new-password'
              }
    end

    f.inputs 'Twilio Lookup API v2 Data Packages', class: 'data-packages' do
      div style: 'background: #e7f3ff; padding: 15px; border-radius: 8px; margin-bottom: 20px;' do
        h4 'Configure which data packages to fetch with each lookup:', style: 'margin-top: 0;'
        para 'Each enabled package may incur additional costs. See ', style: 'margin: 0;'
        link_to 'Twilio Lookup pricing', 'https://www.twilio.com/lookup/pricing', target: '_blank'
        span ' for details.'
      end

      f.input :enable_line_type_intelligence,
              label: '📡 Line Type Intelligence',
              hint: 'Get detailed line type info (mobile, landline, VoIP, etc.) with carrier details. <strong>Worldwide coverage.</strong>',
              input_html: { checked: true }

      f.input :enable_caller_name,
              label: '👤 Caller Name (CNAM)',
              hint: 'Get caller name and type information. <strong>US numbers only.</strong>',
              input_html: { checked: true }

      f.input :enable_sms_pumping_risk,
              label: '🛡️ SMS Pumping Fraud Risk',
              hint: 'Detect fraud risk with real-time risk scores (0-100). <strong>Essential for fraud prevention.</strong>',
              input_html: { checked: true }

      f.input :enable_sim_swap,
              label: '📱 SIM Swap Detection',
              hint: 'Detect recent SIM changes for security verification. <strong>Limited coverage - requires carrier approval.</strong>',
              input_html: { checked: false }

      f.input :enable_reassigned_number,
              label: '♻️ Reassigned Number Detection',
              hint: 'Check if number has been reassigned to a new user. <strong>US only - requires approval.</strong>',
              input_html: { checked: false }
    end

    f.inputs '📞 Real Phone Validation (RPV)', class: 'real-phone-validation' do
      div style: 'background: #e7f3ff; padding: 15px; border-radius: 8px; margin-bottom: 20px;' do
        h4 'Verify if phone numbers are connected or disconnected:', style: 'margin-top: 0;'
        para 'Uses Twilio Marketplace Add-on to check real-time phone line status.', style: 'margin: 0;'
      end

      f.input :enable_real_phone_validation,
              label: '📞 Enable Real Phone Validation',
              hint: 'Check if phone lines are connected/disconnected in real-time. <strong>$0.06 per lookup.</strong> Enabled by default.',
              input_html: { checked: true }

      f.input :rpv_unique_name,
              label: 'RPV Add-on Unique Name',
              hint: 'The unique name you gave the RPV add-on when installing it in Twilio Console. Find this in Console → Add-ons → Installed Add-ons.',
              placeholder: 'real_phone_validation_rpv_turbo',
              input_html: {
                style: 'font-family: monospace; font-size: 14px;',
                value: f.object.rpv_unique_name || 'real_phone_validation_rpv_turbo'
              }

      div style: 'margin-top: 15px; padding: 10px; background: #d4edda; border-left: 4px solid #28a745; border-radius: 4px;' do
        strong '📊 RPV Returns:'
        ul style: 'margin: 10px 0 0 20px;' do
          li 'Line Status: connected, disconnected, pending, busy, unreachable'
          li 'Is Cell: Y (yes), N (no), V (VoIP)'
          li 'Carrier Name: The carrier handling the number'
          li 'CNAM: Caller Name if available'
        end
      end

      div style: 'margin-top: 15px; padding: 10px; background: #fff3cd; border-left: 4px solid #ffc107; border-radius: 4px;' do
        strong '⚠️ Note: '
        span 'This add-on must be installed in your Twilio Console Marketplace before use.'
      end
    end

    f.inputs '🔄 IceHook Scout (Porting Data)', class: 'icehook-scout' do
      div style: 'background: #e7f3ff; padding: 15px; border-radius: 8px; margin-bottom: 20px;' do
        h4 'Check if phone numbers have been ported:', style: 'margin-top: 0;'
        para 'Uses Twilio Marketplace Add-on to detect number porting and get carrier routing info.', style: 'margin: 0;'
      end

      f.input :enable_icehook_scout,
              label: '🔄 Enable IceHook Scout',
              hint: 'Check if numbers have been ported to a different carrier. Returns ported status, LRN, and operating company info.',
              input_html: { checked: false }

      div style: 'margin-top: 15px; padding: 10px; background: #d4edda; border-left: 4px solid #28a745; border-radius: 4px;' do
        strong '📊 Scout Returns:'
        ul style: 'margin: 10px 0 0 20px;' do
          li 'Ported: true/false - Has the number been ported?'
          li 'Location Routing Number (LRN): The routing number for ported numbers'
          li 'Operating Company: Current carrier handling the number (e.g., Verizon)'
          li 'Operating Company Type: Type of carrier (RBOC, CLEC, etc.)'
        end
      end

      div style: 'margin-top: 15px; padding: 10px; background: #fff3cd; border-left: 4px solid #ffc107; border-radius: 4px;' do
        strong '⚠️ Note: '
        span 'IceHook Scout must be installed in your Twilio Console Marketplace before use.'
      end
    end

    f.inputs 'Notes & Configuration' do
      f.input :notes,
              label: 'Configuration Notes',
              hint: 'Optional: Add notes about your Twilio configuration, rate limits, or special settings',
              input_html: { rows: 4 }
    end

    f.inputs '🏢 Business Intelligence Enrichment', class: 'business-enrichment' do
      div style: 'background: #e7f3ff; padding: 15px; border-radius: 8px; margin-bottom: 20px;' do
        h4 'Enrich business contacts with company data:', style: 'margin-top: 0;'
        para 'Automatically fetch business name, employee count, revenue, industry, and more.', style: 'margin: 0;'
      end

      f.input :enable_business_enrichment,
              label: 'Enable Business Enrichment',
              hint: 'Automatically enrich contacts identified as businesses with company intelligence data'

      f.input :auto_enrich_businesses,
              label: 'Auto-Enrich After Lookup',
              hint: 'Automatically queue business enrichment after successful Twilio lookup'

      f.input :enrichment_confidence_threshold,
              label: 'Confidence Threshold (0-100)',
              hint: 'Only save business data with confidence score above this threshold',
              input_html: { min: 0, max: 100 }

      div style: 'margin-top: 20px; padding: 15px; background: #fff3cd; border-left: 4px solid #ffc107; border-radius: 4px;' do
        strong '🔑 Business Enrichment API Keys'
        para 'Configure API keys for business data providers below:', style: 'margin: 5px 0;'
      end

      f.input :clearbit_api_key,
              label: 'Clearbit API Key',
              hint: 'Premium business intelligence (recommended). Get your key at https://clearbit.com',
              input_html: {
                type: 'password',
                style: 'font-family: monospace; font-size: 14px;',
                autocomplete: 'new-password',
                placeholder: 'sk_...'
              }

      f.input :numverify_api_key,
              label: 'NumVerify API Key',
              hint: 'Basic phone intelligence with business detection. Get free key at https://numverify.com',
              input_html: {
                type: 'password',
                style: 'font-family: monospace; font-size: 14px;',
                autocomplete: 'new-password'
              }

      div style: 'margin-top: 15px; padding: 10px; background: #d1ecf1; border-left: 4px solid #0c5460; border-radius: 4px;' do
        strong '💡 Provider Priority: '
        span 'Clearbit → NumVerify → Twilio CNAM (fallback)'
      end
    end

    f.inputs '🛡️ Trust Hub Business Verification', class: 'trust-hub' do
      div style: 'background: #e7f3ff; padding: 15px; border-radius: 8px; margin-bottom: 20px;' do
        h4 'Verify businesses with Twilio Trust Hub:', style: 'margin-top: 0;'
        para "Trust Hub provides regulatory compliance and business verification through Twilio's platform.",
             style: 'margin: 0;'
      end

      f.input :enable_trust_hub,
              label: 'Enable Trust Hub Verification',
              hint: 'Automatically verify business contacts using Twilio Trust Hub API for compliance and authenticity'

      f.input :auto_create_trust_hub_profiles,
              label: 'Auto-Create Trust Hub Profiles',
              hint: 'Automatically create draft Trust Hub customer profiles for verified businesses (requires manual document submission)',
              input_html: { checked: false }

      f.input :trust_hub_reverification_days,
              label: 'Re-verification Interval (days)',
              hint: 'How often to re-check Trust Hub verification status (default: 90 days)',
              input_html: { min: 1, max: 365, value: 90 }

      div style: 'margin-top: 20px; padding: 15px; background: #fff3cd; border-left: 4px solid #ffc107; border-radius: 4px;' do
        strong '🔑 Trust Hub Configuration'
        para 'Configure your Trust Hub policy and webhook settings:', style: 'margin: 5px 0;'
      end

      f.input :trust_hub_policy_sid,
              label: 'Trust Hub Policy SID',
              hint: 'Your Trust Hub policy SID from Twilio Console (e.g., RNxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx). Leave blank to use default business profile policy.',
              input_html: {
                style: 'font-family: monospace; font-size: 14px;',
                placeholder: 'RNxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
              }

      f.input :trust_hub_webhook_url,
              label: 'Trust Hub Webhook URL',
              hint: 'Optional: URL to receive Trust Hub status update webhooks from Twilio',
              input_html: {
                type: 'url',
                placeholder: 'https://your-domain.com/webhooks/trust_hub'
              }

      div style: 'margin-top: 15px; padding: 10px; background: #d1ecf1; border-left: 4px solid #0c5460; border-radius: 4px;' do
        strong '📋 Trust Hub Features:'
        ul style: 'margin: 10px 0 0 20px;' do
          li 'Business verification and compliance validation'
          li 'Regulatory status checking for messaging compliance'
          li 'Customer profile management'
          li 'Verification score calculation (0-100)'
          li 'Automatic re-verification for pending/rejected profiles'
        end
      end

      div style: 'margin-top: 15px; padding: 15px; background: #fff3cd; border-left: 4px solid #ffc107; border-radius: 4px;' do
        strong '⚠️ Important Notes:'
        ul style: 'margin: 10px 0 0 20px;' do
          li 'Trust Hub verification may require manual document submission'
          li 'Draft profiles are created automatically but need documents to be submitted'
          li 'Verification typically takes 1-3 business days after submission'
          li 'Uses your Twilio API credentials configured above'
        end
      end
    end

    f.inputs '✉️ Email Enrichment & Verification', class: 'email-enrichment' do
      div style: 'background: #e7f3ff; padding: 15px; border-radius: 8px; margin-bottom: 20px;' do
        h4 'Find and verify email addresses for contacts:', style: 'margin-top: 0;'
        para 'Automatically discover professional email addresses and verify their deliverability.', style: 'margin: 0;'
      end

      f.input :enable_email_enrichment,
              label: 'Enable Email Enrichment',
              hint: 'Automatically find and verify email addresses for contacts after business enrichment'

      div style: 'margin-top: 20px; padding: 15px; background: #fff3cd; border-left: 4px solid #ffc107; border-radius: 4px;' do
        strong '🔑 Email Enrichment API Keys'
        para 'Configure API keys for email finding and verification providers:', style: 'margin: 5px 0;'
      end

      f.input :hunter_api_key,
              label: 'Hunter.io API Key',
              hint: 'Email finding and verification service. Get your key at https://hunter.io',
              input_html: {
                type: 'password',
                style: 'font-family: monospace; font-size: 14px;',
                autocomplete: 'new-password'
              }

      f.input :zerobounce_api_key,
              label: 'ZeroBounce API Key',
              hint: 'Email verification service. Get your key at https://www.zerobounce.net',
              input_html: {
                type: 'password',
                style: 'font-family: monospace; font-size: 14px;',
                autocomplete: 'new-password'
              }

      div style: 'margin-top: 15px; padding: 10px; background: #d1ecf1; border-left: 4px solid #0c5460; border-radius: 4px;' do
        strong '💡 Email Discovery: '
        span 'Hunter.io (finding) → ZeroBounce (verification) → Clearbit Email (fallback)'
      end
    end

    f.inputs '🔍 Duplicate Detection & Merging', class: 'duplicate-detection' do
      div style: 'background: #e7f3ff; padding: 15px; border-radius: 8px; margin-bottom: 20px;' do
        h4 'Identify and merge duplicate contacts:', style: 'margin-top: 0;'
        para 'Uses fuzzy matching to find duplicates by phone, email, and business name.', style: 'margin: 0;'
      end

      f.input :enable_duplicate_detection,
              label: 'Enable Duplicate Detection',
              hint: 'Automatically check for duplicate contacts after enrichment'

      f.input :duplicate_confidence_threshold,
              label: 'Confidence Threshold (0-100)',
              hint: 'Show duplicates with confidence score above this threshold (recommended: 70-80)',
              input_html: { min: 0, max: 100, value: 75 }

      f.input :auto_merge_duplicates,
              label: 'Auto-Merge High Confidence Duplicates',
              hint: 'Automatically merge contacts with 95%+ confidence match (use with caution)',
              input_html: { checked: false }

      div style: 'margin-top: 15px; padding: 15px; background: #fff3cd; border-left: 4px solid #ffc107; border-radius: 4px;' do
        strong '⚠️ Auto-Merge Warning: '
        para 'Auto-merging is permanent. Review duplicates manually before enabling this feature.',
             style: 'margin: 5px 0 0 0;'
      end
    end

    f.inputs '🤖 AI Assistant (GPT Integration)', class: 'ai-assistant' do
      div style: 'background: #e7f3ff; padding: 15px; border-radius: 8px; margin-bottom: 20px;' do
        h4 'Enable AI-powered features:', style: 'margin-top: 0;'
        para 'Natural language search, sales intelligence, and automated outreach generation.', style: 'margin: 0;'
      end

      f.input :enable_ai_features,
              label: 'Enable AI Features',
              hint: 'Unlock AI assistant, natural language search, and intelligent recommendations'

      div style: 'margin-top: 20px; padding: 15px; background: #fff3cd; border-left: 4px solid #ffc107; border-radius: 4px;' do
        strong '🔑 OpenAI API Configuration'
        para 'Configure your OpenAI API key to enable AI features:', style: 'margin: 5px 0;'
      end

      f.input :openai_api_key,
              label: 'OpenAI API Key',
              hint: 'Get your API key at https://platform.openai.com/api-keys',
              input_html: {
                type: 'password',
                style: 'font-family: monospace; font-size: 14px;',
                autocomplete: 'new-password',
                placeholder: 'sk-...'
              }

      f.input :ai_model,
              label: 'AI Model',
              as: :select,
              collection: [
                ['GPT-4o (Recommended - Fast & Smart)', 'gpt-4o'],
                ['GPT-4o-mini (Budget-Friendly)', 'gpt-4o-mini'],
                ['GPT-4 Turbo (Most Capable)', 'gpt-4-turbo'],
                ['GPT-3.5 Turbo (Fastest)', 'gpt-3.5-turbo']
              ],
              hint: 'Choose the AI model for intelligence features (gpt-4o-mini recommended for sales use)',
              input_html: { selected: 'gpt-4o-mini' }

      f.input :ai_max_tokens,
              label: 'Max Response Tokens',
              hint: 'Maximum tokens for AI responses (500-2000 recommended)',
              input_html: { min: 100, max: 4000, value: 1000 }

      div style: 'margin-top: 15px; padding: 10px; background: #d1ecf1; border-left: 4px solid #0c5460; border-radius: 4px;' do
        strong '💡 AI Features: '
        ul style: 'margin: 10px 0 0 20px;' do
          li 'Natural language contact search'
          li 'Sales intelligence and recommendations'
          li 'Automated outreach message generation'
          li 'Data insights and trend analysis'
        end
      end
    end

    f.inputs '🌐 OpenRouter (Multi-Model AI)', class: 'openrouter' do
      div style: 'background: #e7f3ff; padding: 15px; border-radius: 8px; margin-bottom: 20px;' do
        h4 'Access 100+ AI models through one API:', style: 'margin-top: 0;'
        para 'OpenRouter provides access to OpenAI, Anthropic, Google, Meta, and many more models.', style: 'margin: 0;'
      end

      f.input :enable_openrouter,
              label: 'Enable OpenRouter',
              hint: 'Use OpenRouter as an alternative AI provider (overrides OpenAI when selected)'

      f.input :openrouter_api_key,
              label: 'OpenRouter API Key',
              hint: 'Get your API key at https://openrouter.ai/keys',
              input_html: {
                type: 'password',
                style: 'font-family: monospace; font-size: 14px;',
                autocomplete: 'new-password',
                placeholder: 'sk-or-...'
              }

      f.input :openrouter_model,
              label: 'OpenRouter Model',
              hint: 'Enter any model ID from openrouter.ai/models (e.g., anthropic/claude-3.5-sonnet, openai/gpt-4o)',
              input_html: {
                style: 'font-family: monospace; font-size: 14px;',
                placeholder: 'anthropic/claude-3.5-sonnet',
                autocomplete: 'off'
              }

      div style: 'margin: 10px 0 15px 20%; padding: 10px; background: #f8f9fa; border-radius: 6px; font-size: 13px;' do
        strong 'Popular models: '
        span 'anthropic/claude-3.5-sonnet • openai/gpt-4o • google/gemini-pro-1.5 • meta-llama/llama-3.1-70b-instruct', style: 'color: #666;'
        div style: 'margin-top: 5px;' do
          link_to 'Browse all models →', 'https://openrouter.ai/models', target: '_blank', style: 'color: #0066cc;'
        end
      end

      f.input :preferred_llm_provider,
              label: 'Preferred AI Provider',
              as: :select,
              collection: [
                ['OpenAI (Direct)', 'openai'],
                ['OpenRouter (Multi-Model)', 'openrouter'],
                ['Anthropic (Direct)', 'anthropic'],
                ['Google AI (Direct)', 'google']
              ],
              hint: 'Which AI provider to use by default for AI features'

      div style: 'margin-top: 15px; padding: 10px; background: #d1ecf1; border-left: 4px solid #0c5460; border-radius: 4px;' do
        strong '💡 Why OpenRouter? '
        ul style: 'margin: 10px 0 0 20px;' do
          li 'Single API key for 100+ models'
          li 'Easy model switching without code changes'
          li 'Automatic fallbacks if a model is unavailable'
          li 'Usage-based pricing across all providers'
        end
      end
    end

    f.inputs '📍 Business Directory / Zipcode Lookup', class: 'business-directory' do
      div style: 'background: #e7f3ff; padding: 15px; border-radius: 8px; margin-bottom: 20px;' do
        h4 'Search for businesses by zipcode:', style: 'margin-top: 0;'
        para 'Automatically find and import businesses from specific geographic areas.', style: 'margin: 0;'
      end

      f.input :enable_zipcode_lookup,
              label: 'Enable Zipcode Business Lookup',
              hint: 'Allow searching and importing businesses by zipcode from business directories'

      f.input :results_per_zipcode,
              label: 'Results Per Zipcode',
              hint: 'Max businesses per zipcode. Yelp max: 240, Google max: 60. Combined: up to 300.',
              input_html: { min: 1, max: 300 }

      f.input :auto_enrich_zipcode_results,
              label: 'Auto-Enrich Imported Businesses',
              hint: 'Automatically run phone lookup and email enrichment on newly imported businesses',
              input_html: { checked: true }

      div style: 'margin-top: 20px; padding: 15px; background: #fff3cd; border-left: 4px solid #ffc107; border-radius: 4px;' do
        strong '🔑 Business Directory API Keys'
        para 'Configure at least one API to enable zipcode lookup:', style: 'margin: 5px 0;'
      end

      f.input :google_places_api_key,
              label: 'Google Places API Key',
              hint: 'Recommended for comprehensive business data. Get your key at https://console.cloud.google.com/apis',
              input_html: {
                type: 'password',
                style: 'font-family: monospace; font-size: 14px;',
                autocomplete: 'new-password',
                placeholder: 'AIza...'
              }

      f.input :yelp_api_key,
              label: 'Yelp Fusion API Key',
              hint: 'Alternative/fallback source. Get your key at https://www.yelp.com/developers',
              input_html: {
                type: 'password',
                style: 'font-family: monospace; font-size: 14px;',
                autocomplete: 'new-password'
              }

      div style: 'margin-top: 15px; padding: 10px; background: #d1ecf1; border-left: 4px solid #0c5460; border-radius: 4px;' do
        strong '💡 Provider Priority: '
        span 'Google Places (first) → Yelp (fallback)'
        para ' ', style: 'margin: 10px 0 0 0;'
        strong 'Features:'
        ul style: 'margin: 5px 0 0 20px;' do
          li 'Single or bulk zipcode lookup'
          li 'Automatic duplicate prevention'
          li 'Updates existing businesses instead of duplicating'
          li 'Imports business name, address, phone, website'
        end
      end
    end

    f.inputs '🏠 Address Enrichment & Verizon Coverage', class: 'address-enrichment' do
      div style: 'background: #e7f3ff; padding: 15px; border-radius: 8px; margin-bottom: 20px;' do
        h4 'Find consumer addresses and check Verizon home internet availability:', style: 'margin-top: 0;'
        para 'For consumers only: Find residential addresses and automatically check if they qualify for Verizon 5G/LTE Home Internet.',
             style: 'margin: 0;'
      end

      f.input :enable_address_enrichment,
              label: 'Enable Address Enrichment (Consumers Only)',
              hint: 'Find residential addresses for consumer contacts from phone numbers'

      f.input :enable_verizon_coverage_check,
              label: 'Enable Verizon Coverage Check',
              hint: 'Automatically check if consumer addresses qualify for Verizon 5G/LTE Home Internet'

      f.input :auto_check_verizon_coverage,
              label: 'Auto-Check After Address Found',
              hint: 'Automatically run Verizon coverage check when a valid address is found',
              input_html: { checked: true }

      div style: 'margin-top: 20px; padding: 15px; background: #fff3cd; border-left: 4px solid #ffc107; border-radius: 4px;' do
        strong '🔑 Verizon FWA API Credentials (Optional)'
        para 'For official Verizon API access. Leave blank to use public serviceability check.', style: 'margin: 5px 0;'
      end

      f.input :verizon_account_name,
              label: 'Verizon Account Name',
              hint: 'Your Verizon ThingSpace account name for FWA API access',
              input_html: {
                style: 'font-family: monospace; font-size: 14px;',
                placeholder: 'Your account name'
              }

      f.input :verizon_api_key,
              label: 'Verizon API Key',
              hint: 'API key from Verizon ThingSpace developer portal',
              input_html: {
                type: 'password',
                style: 'font-family: monospace; font-size: 14px;',
                autocomplete: 'new-password'
              }

      f.input :verizon_api_secret,
              label: 'Verizon API Secret',
              hint: 'API secret from Verizon ThingSpace developer portal',
              input_html: {
                type: 'password',
                style: 'font-family: monospace; font-size: 14px;',
                autocomplete: 'new-password'
              }

      div style: 'margin-top: 15px; padding: 10px; background: #d1ecf1; border-left: 4px solid #0c5460; border-radius: 4px;' do
        strong '📍 How it works:'
        ul style: 'margin: 10px 0 0 20px;' do
          li 'Address lookup runs only for consumer (non-business) contacts'
          li 'Uses Whitepages or TrueCaller to find residential address'
          li 'If address found and Verizon check enabled → checks 5G/LTE/Fios availability'
          li 'With API creds: Uses official Verizon FWA API for accurate results'
          li 'Without API creds: Uses public serviceability check (limited)'
        end
      end

      div style: 'margin-top: 15px; padding: 15px; background: #d4edda; border-left: 4px solid #28a745; border-radius: 4px;' do
        strong '✅ Verizon Products Checked:'
        ul style: 'margin: 10px 0 0 20px;' do
          li '5G Home Internet (fastest, limited availability)'
          li 'LTE Home Internet (wider availability)'
          li 'Fios (fiber, if available at address)'
        end
      end
    end

    f.actions do
      f.action :submit, label: 'Save Credentials', button_html: { class: 'button primary' }
      f.action :cancel, label: 'Cancel'
    end
  end

  # ========================================
  # Show Page
  # ========================================
  show do
    panel 'Twilio API Credentials' do
      attributes_table_for twilio_credential do
        row 'Account SID' do |cred|
          div do
            # Show partially masked
            span "#{cred.account_sid[0..5]}***#{cred.account_sid[-4..]}",
                 style: 'font-family: monospace; font-size: 14px;'
            span ' (masked for security)', style: 'color: #6c757d; font-size: 12px; margin-left: 10px;'
          end
        end

        row 'Auth Token' do
          div do
            span '••••••••••••••••••••••••••••••••', style: 'font-family: monospace;'
            status_tag 'Configured', class: 'completed', style: 'margin-left: 10px;'
          end
        end

        row 'Created At' do |cred|
          cred.created_at.strftime('%B %d, %Y at %H:%M')
        end

        row 'Last Updated' do |cred|
          cred.updated_at.strftime('%B %d, %Y at %H:%M')
        end
      end
    end

    panel '🔧 Lookup API v2 Data Packages Configuration' do
      attributes_table_for twilio_credential do
        row 'Line Type Intelligence' do |cred|
          if cred.enable_line_type_intelligence
            status_tag 'Enabled', class: 'ok'
          else
            status_tag 'Disabled', class: 'error'
          end
        end

        row 'Caller Name (CNAM)' do |cred|
          if cred.enable_caller_name
            status_tag 'Enabled', class: 'ok'
          else
            status_tag 'Disabled', class: 'error'
          end
        end

        row 'SMS Pumping Risk Detection' do |cred|
          if cred.enable_sms_pumping_risk
            status_tag 'Enabled', class: 'ok'
          else
            status_tag 'Disabled', class: 'error'
          end
        end

        row 'SIM Swap Detection' do |cred|
          if cred.enable_sim_swap
            status_tag 'Enabled', class: 'warning'
          else
            status_tag 'Disabled', class: 'default'
          end
        end

        row 'Reassigned Number Detection' do |cred|
          if cred.enable_reassigned_number
            status_tag 'Enabled', class: 'warning'
          else
            status_tag 'Disabled', class: 'default'
          end
        end

        row 'API Fields Parameter' do |cred|
          if cred.data_packages.present?
            code cred.data_packages,
                 style: 'background: #f8f9fa; padding: 5px 10px; border-radius: 4px; font-family: monospace;'
          else
            span 'No data packages enabled (basic lookup only)', style: 'color: #6c757d;'
          end
        end
      end

      div style: 'margin-top: 15px; padding: 15px; background: #fff3cd; border-left: 4px solid #ffc107; border-radius: 4px;' do
        strong '💰 Cost Information: '
        para 'Each enabled data package incurs additional API costs per lookup. Review Twilio pricing before enabling.',
             style: 'margin: 5px 0 0 0;'
      end
    end

    panel '📞 Real Phone Validation (RPV)' do
      attributes_table_for twilio_credential do
        row 'Real Phone Validation' do |cred|
          if cred.enable_real_phone_validation
            status_tag 'Enabled', class: 'ok'
          else
            status_tag 'Disabled', class: 'error'
          end
        end

        row 'Add-on Unique Name' do |cred|
          unique_name = cred.rpv_unique_name.presence || 'real_phone_validation_rpv_turbo'
          code unique_name,
               style: 'background: #f8f9fa; padding: 5px 10px; border-radius: 4px; font-family: monospace;'
        end
      end

      div style: 'margin-top: 15px; padding: 15px; background: #e7f3ff; border-left: 4px solid #0c5460; border-radius: 4px;' do
        strong '📊 RPV Data Returned:'
        ul style: 'margin: 10px 0 0 20px;' do
          li 'Line Status: connected, disconnected, pending, busy, unreachable'
          li 'Is Cell: Y (yes), N (no), V (VoIP)'
          li 'Carrier Name: The carrier handling the number'
          li 'CNAM: Caller Name if available'
        end
      end

      div style: 'margin-top: 15px; padding: 15px; background: #fff3cd; border-left: 4px solid #ffc107; border-radius: 4px;' do
        strong '💰 Cost: '
        span '$0.06 per lookup'
      end
    end

    panel '🔄 IceHook Scout (Porting Data)' do
      attributes_table_for twilio_credential do
        row 'IceHook Scout' do |cred|
          if cred.enable_icehook_scout
            status_tag 'Enabled', class: 'ok'
          else
            status_tag 'Disabled', class: 'error'
          end
        end
      end

      div style: 'margin-top: 15px; padding: 15px; background: #e7f3ff; border-left: 4px solid #0c5460; border-radius: 4px;' do
        strong '📊 Scout Data Returned:'
        ul style: 'margin: 10px 0 0 20px;' do
          li 'Ported: true/false - Has the number been ported to a different carrier?'
          li 'Location Routing Number (LRN): The routing number for ported numbers'
          li 'Operating Company: Current carrier handling the number (e.g., Verizon)'
          li 'Operating Company Type: Type of carrier (RBOC, CLEC, etc.)'
        end
      end

      div style: 'margin-top: 15px; padding: 15px; background: #fff3cd; border-left: 4px solid #ffc107; border-radius: 4px;' do
        strong '⚠️ Note: '
        span 'IceHook Scout must be installed in your Twilio Console Marketplace before use.'
      end
    end

    panel '📝 Configuration Notes' do
      if twilio_credential.notes.present?
        div style: 'background: #f8f9fa; padding: 15px; border-radius: 8px; white-space: pre-wrap;' do
          twilio_credential.notes
        end
      else
        para 'No configuration notes.', style: 'color: #6c757d;'
      end
    end

    panel '🏢 Business Intelligence Enrichment' do
      attributes_table_for twilio_credential do
        row 'Business Enrichment' do |cred|
          if cred.enable_business_enrichment
            status_tag 'Enabled', class: 'ok'
          else
            status_tag 'Disabled', class: 'error'
          end
        end

        row 'Auto-Enrich After Lookup' do |cred|
          if cred.auto_enrich_businesses
            status_tag 'Yes', class: 'ok'
          else
            status_tag 'No', class: 'default'
          end
        end

        row 'Confidence Threshold' do |cred|
          "#{cred.enrichment_confidence_threshold}/100"
        end

        row 'Clearbit API' do |cred|
          if cred.clearbit_api_key.present?
            status_tag 'Configured', class: 'ok'
          else
            span 'Not configured', style: 'color: #6c757d;'
          end
        end

        row 'NumVerify API' do |cred|
          if cred.numverify_api_key.present?
            status_tag 'Configured', class: 'ok'
          else
            span 'Not configured', style: 'color: #6c757d;'
          end
        end
      end

      div style: 'margin-top: 15px; padding: 15px; background: #e7f3ff; border-left: 4px solid #0c5460; border-radius: 4px;' do
        strong '📊 Business Data Collected:'
        ul style: 'margin: 10px 0 0 20px;' do
          li 'Company name, legal name, and description'
          li 'Employee count and revenue estimates'
          li 'Industry, category, and business type'
          li 'Location (address, city, state, country)'
          li 'Contact info (website, email domain, social media)'
          li 'Technology stack and company tags'
        end
      end
    end

    panel '🛡️ Trust Hub Business Verification' do
      attributes_table_for twilio_credential do
        row 'Trust Hub Verification' do |cred|
          if cred.enable_trust_hub
            status_tag 'Enabled', class: 'ok'
          else
            status_tag 'Disabled', class: 'error'
          end
        end

        row 'Auto-Create Profiles' do |cred|
          if cred.auto_create_trust_hub_profiles
            status_tag 'Yes', class: 'warning'
          else
            status_tag 'No', class: 'default'
          end
        end

        row 'Re-verification Interval' do |cred|
          "#{cred.trust_hub_reverification_days || 90} days"
        end

        row 'Trust Hub Policy SID' do |cred|
          if cred.trust_hub_policy_sid.present?
            code cred.trust_hub_policy_sid,
                 style: 'background: #f8f9fa; padding: 5px 10px; border-radius: 4px; font-family: monospace;'
          else
            span 'Using default policy', style: 'color: #6c757d;'
          end
        end

        row 'Webhook URL' do |cred|
          if cred.trust_hub_webhook_url.present?
            link_to cred.trust_hub_webhook_url, cred.trust_hub_webhook_url, target: '_blank',
                                                                            style: 'font-family: monospace; font-size: 12px;'
          else
            span 'Not configured', style: 'color: #6c757d;'
          end
        end
      end

      div style: 'margin-top: 15px; padding: 15px; background: #e7f3ff; border-left: 4px solid #0c5460; border-radius: 4px;' do
        strong '🔐 Trust Hub Data Collected:'
        ul style: 'margin: 10px 0 0 20px;' do
          li 'Business verification status and score'
          li 'Customer profile SID'
          li 'Regulatory compliance status'
          li 'Business registration details'
          li 'Verification checks passed/failed'
          li 'Compliance type and region'
        end
      end

      if twilio_credential.enable_trust_hub
        # Show stats
        verified_count = Contact.where(trust_hub_verified: true).count
        total_checked = Contact.where(trust_hub_enriched: true).count
        pending_count = Contact.where(trust_hub_status: %w[pending-review in-review]).count

        div style: 'margin-top: 15px; padding: 15px; background: #fff3cd; border-left: 4px solid #ffc107; border-radius: 4px;' do
          strong '📊 Trust Hub Stats:'
          ul style: 'margin: 10px 0 0 20px; list-style: none; padding-left: 0;' do
            li "Total Businesses Checked: #{total_checked}"
            li "Verified Businesses: #{verified_count} (#{total_checked > 0 ? (verified_count.to_f / total_checked * 100).round(1) : 0}%)"
            li "Pending Verification: #{pending_count}"
          end
        end
      end
    end

    panel '✉️ Email Enrichment & Verification' do
      attributes_table_for twilio_credential do
        row 'Email Enrichment' do |cred|
          if cred.enable_email_enrichment
            status_tag 'Enabled', class: 'ok'
          else
            status_tag 'Disabled', class: 'error'
          end
        end

        row 'Hunter.io API' do |cred|
          if cred.hunter_api_key.present?
            status_tag 'Configured', class: 'ok'
          else
            span 'Not configured', style: 'color: #6c757d;'
          end
        end

        row 'ZeroBounce API' do |cred|
          if cred.zerobounce_api_key.present?
            status_tag 'Configured', class: 'ok'
          else
            span 'Not configured', style: 'color: #6c757d;'
          end
        end
      end

      div style: 'margin-top: 15px; padding: 15px; background: #e7f3ff; border-left: 4px solid #0c5460; border-radius: 4px;' do
        strong '📧 Email Data Collected:'
        ul style: 'margin: 10px 0 0 20px;' do
          li 'Primary and additional email addresses'
          li 'Email verification status and deliverability score'
          li 'Contact person name, title, and department'
          li 'Seniority level and role information'
          li 'Social media profiles (LinkedIn, Twitter, Facebook)'
        end
      end
    end

    panel '🔍 Duplicate Detection & Merging' do
      attributes_table_for twilio_credential do
        row 'Duplicate Detection' do |cred|
          if cred.enable_duplicate_detection
            status_tag 'Enabled', class: 'ok'
          else
            status_tag 'Disabled', class: 'error'
          end
        end

        row 'Confidence Threshold' do |cred|
          "#{cred.duplicate_confidence_threshold || 75}/100"
        end

        row 'Auto-Merge Duplicates' do |cred|
          if cred.auto_merge_duplicates
            div do
              status_tag 'Yes', class: 'warning'
              span ' (95%+ confidence only)', style: 'color: #6c757d; margin-left: 10px;'
            end
          else
            status_tag 'No', class: 'default'
          end
        end
      end

      div style: 'margin-top: 15px; padding: 15px; background: #fff3cd; border-left: 4px solid #ffc107; border-radius: 4px;' do
        strong '🎯 Duplicate Matching Strategy:'
        ul style: 'margin: 10px 0 0 20px;' do
          li 'Phone number exact and fuzzy matching'
          li 'Email address comparison'
          li 'Business name and location similarity'
          li 'Personal name fuzzy matching (Levenshtein distance)'
          li 'Fingerprinting for fast duplicate detection'
        end
      end
    end

    panel '🤖 AI Assistant Configuration' do
      attributes_table_for twilio_credential do
        row 'AI Features' do |cred|
          if cred.enable_ai_features
            status_tag 'Enabled', class: 'ok'
          else
            status_tag 'Disabled', class: 'error'
          end
        end

        row 'OpenAI API Key' do |cred|
          if cred.openai_api_key.present?
            div do
              span 'sk-•••••••••••••••••••••••', style: 'font-family: monospace;'
              status_tag 'Configured', class: 'ok', style: 'margin-left: 10px;'
            end
          else
            span 'Not configured', style: 'color: #6c757d;'
          end
        end

        row 'AI Model' do |cred|
          if cred.ai_model.present?
            status_tag cred.ai_model, class: 'default'
          else
            'gpt-4o-mini (default)'
          end
        end

        row 'Max Response Tokens' do |cred|
          cred.ai_max_tokens || 1000
        end
      end

      div style: 'margin-top: 15px; padding: 15px; background: #e7f3ff; border-left: 4px solid #0c5460; border-radius: 4px;' do
        strong '🚀 AI Features Available:'
        ul style: 'margin: 10px 0 0 20px;' do
          li 'Natural language contact search - Find contacts with plain English queries'
          li 'Sales intelligence - Get AI-powered insights about your contacts'
          li 'Smart recommendations - Discover trends and opportunities'
          li 'Outreach generation - AI-generated personalized messages'
        end
      end

      if twilio_credential.enable_ai_features && twilio_credential.openai_api_key.present?
        div style: 'margin-top: 15px; padding: 15px; background: #d4edda; border-left: 4px solid #28a745; border-radius: 4px;' do
          strong '✅ AI Assistant Ready!'
          para 'Visit the AI Assistant page to start using natural language search and intelligence features.',
               style: 'margin: 5px 0 0 0;'
          link_to 'Go to AI Assistant →', admin_ai_assistant_path, class: 'button primary',
                                                                   style: 'margin-top: 10px; display: inline-block;'
        end
      end
    end

    panel '🌐 OpenRouter Configuration' do
      attributes_table_for twilio_credential do
        row 'OpenRouter' do |cred|
          if cred.enable_openrouter
            status_tag 'Enabled', class: 'ok'
          else
            status_tag 'Disabled', class: 'error'
          end
        end

        row 'OpenRouter API Key' do |cred|
          if cred.openrouter_api_key.present?
            div do
              span 'sk-or-•••••••••••••••••••', style: 'font-family: monospace;'
              status_tag 'Configured', class: 'ok', style: 'margin-left: 10px;'
            end
          else
            span 'Not configured', style: 'color: #6c757d;'
          end
        end

        row 'OpenRouter Model' do |cred|
          if cred.openrouter_model.present?
            status_tag cred.openrouter_model, class: 'default'
          else
            span 'Not selected', style: 'color: #6c757d;'
          end
        end

        row 'Preferred AI Provider' do |cred|
          provider = cred.preferred_llm_provider || 'openai'
          case provider
          when 'openrouter'
            status_tag 'OpenRouter', class: 'ok'
          when 'anthropic'
            status_tag 'Anthropic', class: 'default'
          when 'google'
            status_tag 'Google AI', class: 'default'
          else
            status_tag 'OpenAI (Direct)', class: 'default'
          end
        end
      end

      div style: 'margin-top: 15px; padding: 15px; background: #e7f3ff; border-left: 4px solid #0c5460; border-radius: 4px;' do
        strong '🌐 OpenRouter Benefits:'
        ul style: 'margin: 10px 0 0 20px;' do
          li 'Access 100+ AI models with a single API key'
          li 'Switch between OpenAI, Anthropic, Google, Meta models'
          li 'Automatic fallbacks when a model is unavailable'
          li 'Usage-based pricing across all providers'
        end
      end

      if twilio_credential.enable_openrouter && twilio_credential.openrouter_api_key.present?
        div style: 'margin-top: 15px; padding: 15px; background: #d4edda; border-left: 4px solid #28a745; border-radius: 4px;' do
          strong '✅ OpenRouter Ready!'
          para "Using model: #{twilio_credential.openrouter_model || 'Default'}",
               style: 'margin: 5px 0 0 0;'
        end
      end
    end

    panel '📍 Business Directory / Zipcode Lookup' do
      attributes_table_for twilio_credential do
        row 'Zipcode Lookup' do |cred|
          if cred.enable_zipcode_lookup
            status_tag 'Enabled', class: 'ok'
          else
            status_tag 'Disabled', class: 'error'
          end
        end

        row 'Results Per Zipcode' do |cred|
          "#{cred.results_per_zipcode || 20} businesses per zipcode"
        end

        row 'Auto-Enrich Results' do |cred|
          if cred.auto_enrich_zipcode_results
            status_tag 'Yes', class: 'ok'
          else
            status_tag 'No', class: 'default'
          end
        end

        row 'Google Places API' do |cred|
          if cred.google_places_api_key.present?
            div do
              span 'AIza•••••••••••••••••••', style: 'font-family: monospace;'
              status_tag 'Configured', class: 'ok', style: 'margin-left: 10px;'
            end
          else
            span 'Not configured', style: 'color: #6c757d;'
          end
        end

        row 'Yelp Fusion API' do |cred|
          if cred.yelp_api_key.present?
            div do
              span '•••••••••••••••••••••••', style: 'font-family: monospace;'
              status_tag 'Configured', class: 'ok', style: 'margin-left: 10px;'
            end
          else
            span 'Not configured', style: 'color: #6c757d;'
          end
        end
      end

      div style: 'margin-top: 15px; padding: 15px; background: #e7f3ff; border-left: 4px solid #0c5460; border-radius: 4px;' do
        strong '🔍 Zipcode Lookup Features:'
        ul style: 'margin: 10px 0 0 20px;' do
          li 'Search for businesses in specific zipcodes'
          li 'Single or bulk zipcode processing'
          li 'Automatic duplicate prevention'
          li 'Updates existing businesses instead of creating duplicates'
          li 'Auto-enrichment with phone validation and email finding'
        end
      end

      if twilio_credential.enable_zipcode_lookup && (twilio_credential.google_places_api_key.present? || twilio_credential.yelp_api_key.present?)
        div style: 'margin-top: 15px; padding: 15px; background: #d4edda; border-left: 4px solid #28a745; border-radius: 4px;' do
          strong '✅ Business Lookup Ready!'
          para 'Visit the Business Lookup page to start searching for businesses by zipcode.',
               style: 'margin: 5px 0 0 0;'
          link_to 'Go to Business Lookup →', admin_business_lookup_path, class: 'button primary',
                                                                         style: 'margin-top: 10px; display: inline-block;'
        end
      end
    end

    panel '🏠 Address Enrichment & Verizon Coverage' do
      attributes_table_for twilio_credential do
        row 'Address Enrichment (Consumers)' do |cred|
          if cred.enable_address_enrichment
            status_tag 'Enabled', class: 'ok'
          else
            status_tag 'Disabled', class: 'error'
          end
        end

        row 'Verizon Coverage Check' do |cred|
          if cred.enable_verizon_coverage_check
            status_tag 'Enabled', class: 'ok'
          else
            status_tag 'Disabled', class: 'error'
          end
        end

        row 'Auto-Check Verizon' do |cred|
          if cred.auto_check_verizon_coverage
            status_tag 'Yes', class: 'ok'
          else
            status_tag 'No', class: 'default'
          end
        end

        row 'Whitepages API' do |cred|
          if cred.whitepages_api_key.present?
            div do
              span '•••••••••••••••••••••••', style: 'font-family: monospace;'
              status_tag 'Configured', class: 'ok', style: 'margin-left: 10px;'
            end
          else
            span 'Not configured', style: 'color: #6c757d;'
          end
        end

        row 'TrueCaller API' do |cred|
          if cred.truecaller_api_key.present?
            div do
              span '•••••••••••••••••••••••', style: 'font-family: monospace;'
              status_tag 'Configured', class: 'ok', style: 'margin-left: 10px;'
            end
          else
            span 'Not configured', style: 'color: #6c757d;'
          end
        end
      end

      div style: 'margin-top: 15px; padding: 15px; background: #e7f3ff; border-left: 4px solid #0c5460; border-radius: 4px;' do
        strong '📍 Address Discovery Process:'
        ul style: 'margin: 10px 0 0 20px;' do
          li 'Runs only for consumer (non-business) contacts'
          li 'Uses phone number to find residential address'
          li 'Validates and verifies address accuracy'
          li 'Stores full address: street, city, state, zipcode'
        end
        para ' ', style: 'margin: 15px 0 0 0;'
        strong '📡 Verizon Coverage Check:'
        ul style: 'margin: 10px 0 0 20px;' do
          li 'Checks availability of 5G Home, LTE Home, and Fios'
          li "Uses Verizon's public availability checker"
          li 'No Verizon API access required'
          li 'Stores availability status and estimated speeds'
          li 'Checks once per 30 days to avoid redundant lookups'
        end
      end

      if twilio_credential.enable_address_enrichment || twilio_credential.enable_verizon_coverage_check
        # Show stats
        consumer_count = Contact.consumers.count
        address_enriched_count = Contact.address_enriched.count
        verizon_checked_count = Contact.verizon_coverage_checked.count
        verizon_available_count = Contact.verizon_home_internet_available.count

        div style: 'margin-top: 15px; padding: 15px; background: #fff3cd; border-left: 4px solid #ffc107; border-radius: 4px;' do
          strong '📊 Quick Stats:'
          ul style: 'margin: 10px 0 0 20px; list-style: none; padding-left: 0;' do
            li "Total Consumers: #{consumer_count}"
            li "Addresses Found: #{address_enriched_count} (#{consumer_count > 0 ? (address_enriched_count.to_f / consumer_count * 100).round(1) : 0}%)"
            li "Verizon Coverage Checked: #{verizon_checked_count}"
            li "Verizon Available: #{verizon_available_count} (#{verizon_checked_count > 0 ? (verizon_available_count.to_f / verizon_checked_count * 100).round(1) : 0}%)"
          end
        end
      end
    end

    panel 'Connection Test' do
      div style: 'padding: 15px; background: #f8f9fa; border-radius: 8px;' do
        client = Twilio::REST::Client.new(twilio_credential.account_sid, twilio_credential.auth_token)
        account = client.api.accounts(twilio_credential.account_sid).fetch

        div style: 'color: #11998e; font-weight: bold; font-size: 16px; margin-bottom: 10px;' do
          '✅ Credentials are valid and working!'
        end

        attributes_table_for account do
          row('Account Name') { account.friendly_name }
          row('Account Status') { status_tag account.status }
          row('Account Type') { account.type }
        end
      rescue Twilio::REST::RestError => e
        div style: 'color: #dc3545; font-weight: bold; font-size: 16px; margin-bottom: 10px;' do
          '❌ Credential Validation Failed'
        end

        div style: 'background: white; padding: 15px; border-left: 4px solid #dc3545; border-radius: 4px; margin-top: 10px;' do
          strong 'Error: '
          span e.message
        end

        div style: 'margin-top: 15px; padding: 10px; background: #fff3cd; border-radius: 4px;' do
          strong 'Troubleshooting:'
          ul style: 'margin: 10px 0 0 20px;' do
            li 'Verify your Account SID and Auth Token are correct'
            li 'Check that your Twilio account is active'
            li 'Ensure you have API access enabled'
          end
        end
      rescue StandardError => e
        div style: 'color: #dc3545;' do
          strong 'Connection Error: '
          span e.message
        end
      end
    end

    panel 'Usage Information' do
      div style: 'background: #e7f3ff; padding: 15px; border-radius: 8px;' do
        h4 'How These Credentials Are Used', style: 'margin-top: 0;'

        ul do
          li 'Background jobs use these credentials to call the Twilio Lookup API'
          li 'Credentials are cached for 1 hour to reduce database queries'
          li 'Only one set of credentials can be active at a time'
          li 'Updating credentials will clear the cache and use new values immediately'
        end

        div style: 'margin-top: 15px; padding: 10px; background: white; border-radius: 4px;' do
          strong 'Security Recommendations:'
          ul style: 'margin: 10px 0 0 20px;' do
            li 'Rotate credentials regularly'
            li 'Use environment variables in production'
            li 'Monitor Twilio console for unusual activity'
            li 'Never commit credentials to version control'
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
    link_to '🔍 Test Connection', test_admin_twilio_credential_path(twilio_credential),
            class: 'button'
  end

  member_action :test, method: :get do
    client = Twilio::REST::Client.new(resource.account_sid, resource.auth_token)
    account = client.api.accounts(resource.account_sid).fetch

    redirect_to resource_path, notice: "✅ Credentials are valid! Account: #{account.friendly_name}"
  rescue Twilio::REST::RestError => e
    redirect_to resource_path, alert: "❌ Credential test failed: #{e.message}"
  rescue StandardError => e
    redirect_to resource_path, alert: "❌ Connection error: #{e.message}"
  end

  # ========================================
  # Controller Customization
  # ========================================
  controller do
    def create
      # Enforce singleton pattern
      if TwilioCredential.any?
        redirect_to edit_admin_twilio_credential_path(TwilioCredential.current || TwilioCredential.first),
                    alert: 'Credentials already exist. Please update them instead.'
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
                :enable_reassigned_number, :enable_real_phone_validation, :rpv_unique_name,
                :notes, :enable_business_enrichment,
                :auto_enrich_businesses, :enrichment_confidence_threshold,
                :clearbit_api_key, :numverify_api_key,
                # Trust Hub verification
                :enable_trust_hub, :trust_hub_policy_sid, :trust_hub_webhook_url,
                :auto_create_trust_hub_profiles, :trust_hub_reverification_days,
                # Email enrichment
                :enable_email_enrichment, :hunter_api_key, :zerobounce_api_key,
                # Duplicate detection
                :enable_duplicate_detection, :duplicate_confidence_threshold, :auto_merge_duplicates,
                # AI configuration
                :enable_ai_features, :openai_api_key, :ai_model, :ai_max_tokens,
                # OpenRouter configuration
                :enable_openrouter, :openrouter_api_key, :openrouter_model, :preferred_llm_provider,
                # Business directory / zipcode lookup
                :enable_zipcode_lookup, :google_places_api_key, :yelp_api_key,
                :results_per_zipcode, :auto_enrich_zipcode_results,
                # Address enrichment & Verizon coverage
                :enable_address_enrichment, :enable_verizon_coverage_check,
                :whitepages_api_key, :truecaller_api_key, :auto_check_verizon_coverage,
                # Verizon FWA API credentials
                :verizon_api_key, :verizon_api_secret, :verizon_account_name,
                # IceHook Scout (porting data)
                :enable_icehook_scout
end
