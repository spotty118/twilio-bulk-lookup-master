# frozen_string_literal: true

ActiveAdmin.register_page 'API Health' do
  menu parent: 'System', priority: 1, label: 'API Health Monitor'

  content title: 'API Health Dashboard' do
    # Define all API providers to monitor
    providers = [
      # Core
      { name: 'Twilio Lookup', key: :twilio, check_method: :check_twilio_health },
      # Business Intelligence
      { name: 'Clearbit', key: :clearbit, check_method: :check_clearbit_health },
      { name: 'NumVerify', key: :numverify, check_method: :check_numverify_health },
      # Email Discovery
      { name: 'Hunter.io', key: :hunter, check_method: :check_hunter_health },
      { name: 'ZeroBounce', key: :zerobounce, check_method: :check_zerobounce_health },
      # Address & Location
      { name: 'Whitepages Pro', key: :whitepages, check_method: :check_whitepages_health },
      { name: 'TrueCaller', key: :truecaller, check_method: :check_truecaller_health },
      { name: 'Google Geocoding', key: :google_geocoding, check_method: :check_google_geocoding_health },
      # Business Directory
      { name: 'Google Places', key: :google_places, check_method: :check_google_places_health },
      { name: 'Yelp Fusion', key: :yelp, check_method: :check_yelp_health },
      # AI/LLM
      { name: 'OpenAI', key: :openai, check_method: :check_openai_health },
      { name: 'Anthropic Claude', key: :anthropic, check_method: :check_anthropic_health },
      { name: 'Google Gemini', key: :google_ai, check_method: :check_google_ai_health },
      # Coverage
      { name: 'Verizon API', key: :verizon, check_method: :check_verizon_health }
    ]

    # Helper to check API health
    def check_api_health(provider)
      credentials = TwilioCredential.current
      unless credentials
        return { healthy: false, status: 'Not configured', response_time: nil, checked_at: Time.current,
                 error: 'No credentials' }
      end

      start_time = Time.current
      result = send(provider[:check_method], credentials)
      response_time = ((Time.current - start_time) * 1000).round

      {
        healthy: result[:healthy],
        status: result[:status],
        response_time: response_time,
        checked_at: Time.current,
        error: result[:error]
      }
    rescue StandardError => e
      {
        healthy: false,
        status: 'Error',
        response_time: nil,
        checked_at: Time.current,
        error: e.message
      }
    end

    # Health check methods for each provider
    def check_twilio_health(credentials)
      unless credentials.account_sid.present? && credentials.auth_token.present?
        return { healthy: false, status: 'Not configured', error: nil }
      end

      client = Twilio::REST::Client.new(credentials.account_sid, credentials.auth_token)
      client.api.accounts(credentials.account_sid).fetch
      { healthy: true, status: 'Operational', error: nil }
    rescue Twilio::REST::RestError => e
      { healthy: false, status: 'API Error', error: e.message }
    end

    def check_clearbit_health(credentials)
      return { healthy: false, status: 'Not configured', error: nil } unless credentials.clearbit_api_key.present?

      response = HTTParty.get('https://company.clearbit.com/v1/domains/find?name=clearbit.com',
                              headers: { 'Authorization' => "Bearer #{credentials.clearbit_api_key}" },
                              timeout: 5)
      { healthy: response.success?, status: response.success? ? 'Operational' : 'API Error', error: nil }
    rescue HTTParty::Error, Timeout::Error => e
      { healthy: false, status: 'Connection Error', error: e.message }
    end

    def check_numverify_health(credentials)
      return { healthy: false, status: 'Not configured', error: nil } unless credentials.numverify_api_key.present?

      response = HTTParty.get('http://apilayer.net/api/validate',
                              query: { access_key: credentials.numverify_api_key, number: '14155552671' },
                              timeout: 5)
      { healthy: response.success?, status: response.success? ? 'Operational' : 'API Error', error: nil }
    rescue HTTParty::Error, Timeout::Error => e
      { healthy: false, status: 'Connection Error', error: e.message }
    end

    def check_hunter_health(credentials)
      return { healthy: false, status: 'Not configured', error: nil } unless credentials.hunter_api_key.present?

      response = HTTParty.get('https://api.hunter.io/v2/account',
                              query: { api_key: credentials.hunter_api_key },
                              timeout: 5)
      { healthy: response.success?, status: response.success? ? 'Operational' : 'API Error', error: nil }
    rescue HTTParty::Error, Timeout::Error => e
      { healthy: false, status: 'Connection Error', error: e.message }
    end

    def check_zerobounce_health(credentials)
      return { healthy: false, status: 'Not configured', error: nil } unless credentials.zerobounce_api_key.present?

      response = HTTParty.get('https://api.zerobounce.net/v2/getcredits',
                              query: { api_key: credentials.zerobounce_api_key },
                              timeout: 5)
      { healthy: response.success?, status: response.success? ? 'Operational' : 'API Error', error: nil }
    rescue HTTParty::Error, Timeout::Error => e
      { healthy: false, status: 'Connection Error', error: e.message }
    end

    def check_whitepages_health(credentials)
      return { healthy: false, status: 'Not configured', error: nil } unless credentials.whitepages_api_key.present?

      { healthy: true, status: 'Configured', error: nil }
    end

    def check_truecaller_health(credentials)
      return { healthy: false, status: 'Not configured', error: nil } unless credentials.truecaller_api_key.present?

      { healthy: true, status: 'Configured', error: nil }
    end

    def check_google_geocoding_health(credentials)
      unless credentials.google_geocoding_api_key.present?
        return { healthy: false, status: 'Not configured',
                 error: nil }
      end

      response = HTTParty.get('https://maps.googleapis.com/maps/api/geocode/json',
                              query: { address: 'San Francisco, CA', key: credentials.google_geocoding_api_key },
                              timeout: 5)
      data = response.parsed_response
      { healthy: data['status'] == 'OK', status: data['status'], error: nil }
    rescue HTTParty::Error, Timeout::Error => e
      { healthy: false, status: 'Connection Error', error: e.message }
    end

    def check_google_places_health(credentials)
      return { healthy: false, status: 'Not configured', error: nil } unless credentials.google_places_api_key.present?

      response = HTTParty.get('https://maps.googleapis.com/maps/api/place/textsearch/json',
                              query: { query: 'restaurants', key: credentials.google_places_api_key },
                              timeout: 5)
      data = response.parsed_response
      { healthy: data['status'] == 'OK', status: data['status'], error: nil }
    rescue HTTParty::Error, Timeout::Error => e
      { healthy: false, status: 'Connection Error', error: e.message }
    end

    def check_yelp_health(credentials)
      return { healthy: false, status: 'Not configured', error: nil } unless credentials.yelp_api_key.present?

      response = HTTParty.get('https://api.yelp.com/v3/businesses/search',
                              headers: { 'Authorization' => "Bearer #{credentials.yelp_api_key}" },
                              query: { location: 'San Francisco', limit: 1 },
                              timeout: 5)
      { healthy: response.success?, status: response.success? ? 'Operational' : 'API Error', error: nil }
    rescue HTTParty::Error, Timeout::Error => e
      { healthy: false, status: 'Connection Error', error: e.message }
    end

    def check_openai_health(credentials)
      return { healthy: false, status: 'Not configured', error: nil } unless credentials.openai_api_key.present?

      response = HTTParty.get('https://api.openai.com/v1/models',
                              headers: { 'Authorization' => "Bearer #{credentials.openai_api_key}" },
                              timeout: 5)
      { healthy: response.success?, status: response.success? ? 'Operational' : 'API Error', error: nil }
    rescue HTTParty::Error, Timeout::Error => e
      { healthy: false, status: 'Connection Error', error: e.message }
    end

    def check_anthropic_health(credentials)
      return { healthy: false, status: 'Not configured', error: nil } unless credentials.anthropic_api_key.present?

      { healthy: true, status: 'Configured', error: nil }
    end

    def check_google_ai_health(credentials)
      return { healthy: false, status: 'Not configured', error: nil } unless credentials.google_ai_api_key.present?

      { healthy: true, status: 'Configured', error: nil }
    end

    def check_verizon_health(credentials)
      unless credentials.verizon_api_key.present? && credentials.verizon_api_secret.present?
        return { healthy: false, status: 'Not configured', error: nil }
      end

      { healthy: true, status: 'Configured', error: nil }
    end

    # Render the dashboard
    panel 'API Provider Health Status' do
      para 'Real-time health monitoring of all integrated API providers. ' \
           'Green = operational, Yellow = configured but not tested, Red = error or not configured.'

      table_for(providers.map { |p| { provider: p, health: check_api_health(p) } }) do
        column 'Provider' do |item|
          status_tag item[:provider][:name], class: 'api-provider-name'
        end

        column 'Status' do |item|
          health = item[:health]
          color = if health[:healthy]
                    :ok
                  else
                    (health[:status] == 'Configured' ? :warning : :error)
                  end
          icon = if health[:healthy]
                   '✅'
                 else
                   (health[:status] == 'Configured' ? '⚠️' : '❌')
                 end

          div class: 'api-status' do
            span icon
            span ' '
            status_tag health[:status], class: color
          end
        end

        column 'Response Time' do |item|
          health = item[:health]
          if health[:response_time]
            color = if health[:response_time] < 500
                      'green'
                    elsif health[:response_time] < 2000
                      'orange'
                    else
                      'red'
                    end
            span "#{health[:response_time]}ms", style: "color: #{color}; font-weight: bold;"
          else
            span 'N/A', style: 'color: gray;'
          end
        end

        column 'Last Checked' do |item|
          time_ago_in_words(item[:health][:checked_at]) + ' ago'
        end

        column 'Details' do |item|
          health = item[:health]
          if health[:error].present?
            span health[:error], style: 'color: red; font-size: 0.9em;'
          else
            span 'OK', style: 'color: green;'
          end
        end
      end
    end

    # Summary statistics
    panel 'Summary' do
      results = providers.map { |p| check_api_health(p) }
      healthy_count = results.count { |r| r[:healthy] }
      configured_count = results.count { |r| r[:status] == 'Configured' }
      error_count = results.count { |r| !r[:healthy] && r[:status] != 'Configured' }

      columns do
        column do
          panel 'Operational APIs' do
            div style: 'text-align: center; padding: 20px;' do
              h2 healthy_count, style: 'color: green; font-size: 3em; margin: 0;'
              para "out of #{providers.count} providers"
            end
          end
        end

        column do
          panel 'Configured (Not Tested)' do
            div style: 'text-align: center; padding: 20px;' do
              h2 configured_count, style: 'color: orange; font-size: 3em; margin: 0;'
              para 'APIs with keys configured'
            end
          end
        end

        column do
          panel 'Errors / Not Configured' do
            div style: 'text-align: center; padding: 20px;' do
              h2 error_count, style: 'color: red; font-size: 3em; margin: 0;'
              para 'Providers with issues'
            end
          end
        end
      end
    end

    # Recent API usage from logs
    if defined?(ApiUsageLog)
      panel 'Recent API Activity (Last 24 Hours)' do
        recent_logs = ApiUsageLog.where('created_at > ?', 24.hours.ago)
                                 .group(:provider)
                                 .select('provider, COUNT(*) as call_count, AVG(response_time_ms) as avg_response_time, SUM(cost) as total_cost')
                                 .order('call_count DESC')

        if recent_logs.any?
          table_for recent_logs do
            column 'Provider' do |log|
              log.provider.titleize
            end
            column 'API Calls' do |log|
              number_with_delimiter(log.call_count)
            end
            column 'Avg Response Time' do |log|
              "#{log.avg_response_time.to_i}ms"
            end
            column 'Total Cost' do |log|
              number_to_currency(log.total_cost)
            end
          end
        else
          para 'No API calls in the last 24 hours', style: 'color: gray; font-style: italic;'
        end
      end
    end
  end
end
