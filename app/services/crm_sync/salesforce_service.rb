require 'net/http'
require 'json'

module CrmSync
  class SalesforceService
    SALESFORCE_API_VERSION = 'v58.0'

    def initialize(contact = nil)
      @contact = contact
      @credentials = TwilioCredential.current
    end

    # Sync contact to Salesforce
    def sync_to_salesforce
      return { success: false, error: 'Salesforce sync not enabled' } unless @credentials&.enable_salesforce_sync
      return { success: false, error: 'CRM sync disabled for this contact' } unless @contact.crm_sync_enabled
      return { success: false, error: 'No access token' } unless valid_access_token?

      start_time = Time.current

      begin
        if @contact.salesforce_id.present?
          # Update existing contact
          result = update_salesforce_contact
        else
          # Create new contact
          result = create_salesforce_contact
        end

        if result[:success]
          @contact.update!(
            salesforce_id: result[:id],
            salesforce_synced_at: Time.current,
            salesforce_sync_status: 'synced',
            last_crm_sync_at: Time.current
          )

          log_api_usage(
            service: 'sync_contact',
            status: 'success',
            response_time_ms: ((Time.current - start_time) * 1000).to_i
          )
        else
          @contact.update!(
            salesforce_sync_status: 'failed',
            crm_sync_errors: (@contact.crm_sync_errors || {}).merge(
              salesforce: { error: result[:error], timestamp: Time.current }
            )
          )

          log_api_usage(
            service: 'sync_contact',
            status: 'failed',
            error_message: result[:error],
            response_time_ms: ((Time.current - start_time) * 1000).to_i
          )
        end

        result
      rescue StandardError => e
        operation = @contact.salesforce_id.present? ? 'update' : 'create'
        Rails.logger.error(
          "Salesforce sync error for contact #{@contact.id} (operation: #{operation}, " \
          "salesforce_id: #{@contact.salesforce_id || 'none'}): #{e.class} - #{e.message}"
        )
        Rails.logger.error(e.backtrace.first(3).join("\n"))
        { success: false, error: e.message }
      end
    end

    # Pull contact from Salesforce
    def pull_from_salesforce(salesforce_id)
      return { success: false, error: 'Salesforce sync not enabled' } unless @credentials&.enable_salesforce_sync
      return { success: false, error: 'No access token' } unless valid_access_token?

      begin
        uri = URI("#{@credentials.salesforce_instance_url}/services/data/#{SALESFORCE_API_VERSION}/sobjects/Contact/#{salesforce_id}")

        response = HttpClient.get(uri, circuit_name: 'salesforce-api') do |request|
          request['Authorization'] = "Bearer #{@credentials.salesforce_access_token}"
        end

        if response.code.to_i == 200
          data = JSON.parse(response.body)
          { success: true, data: data }
        else
          error_data = JSON.parse(response.body) rescue {}
          { success: false, error: error_data['message'] || 'Salesforce API error' }
        end
      rescue HttpClient::TimeoutError, HttpClient::CircuitOpenError => e
        { success: false, error: "Service unavailable: #{e.message}" }
      rescue StandardError => e
        Rails.logger.error(
          "Salesforce pull error (salesforce_id: #{salesforce_id}): #{e.class} - #{e.message}"
        )
        Rails.logger.error(e.backtrace.first(3).join("\n"))
        { success: false, error: e.message }
      end
    end

    # OAuth flow methods
    def self.get_authorization_url(redirect_uri)
      credentials = TwilioCredential.current
      return nil unless credentials&.salesforce_client_id

      params = {
        response_type: 'code',
        client_id: credentials.salesforce_client_id,
        redirect_uri: redirect_uri,
        scope: 'full refresh_token'
      }

      "https://login.salesforce.com/services/oauth2/authorize?#{URI.encode_www_form(params)}"
    end

    def self.exchange_code_for_token(code, redirect_uri)
      credentials = TwilioCredential.current
      return { success: false, error: 'No Salesforce credentials' } unless credentials

      begin
        uri = URI('https://login.salesforce.com/services/oauth2/token')
        request = Net::HTTP::Post.new(uri)
        request.set_form_data(
          grant_type: 'authorization_code',
          client_id: credentials.salesforce_client_id,
          client_secret: credentials.salesforce_client_secret,
          redirect_uri: redirect_uri,
          code: code
        )

        response = Net::HTTP.start(uri.hostname, uri.port,
                                    use_ssl: true,
                                    read_timeout: 15,
                                    open_timeout: 10,
                                    connect_timeout: 10) do |http|
          http.request(request)
        end

        if response.code.to_i == 200
          data = JSON.parse(response.body)
          
          # Salesforce access tokens typically expire in 2 hours
          expires_at = Time.current + 2.hours

          credentials.update!(
            salesforce_access_token: data['access_token'],
            salesforce_refresh_token: data['refresh_token'],
            salesforce_instance_url: data['instance_url'],
            salesforce_token_expires_at: expires_at
          )

          { success: true, data: data }
        else
          error_data = JSON.parse(response.body) rescue {}
          { success: false, error: error_data['error_description'] || 'OAuth error' }
        end
      rescue StandardError => e
        { success: false, error: e.message }
      end
    end

    # Batch sync
    def self.batch_sync(contacts)
      results = { total: contacts.count, synced: 0, failed: 0, errors: [] }

      contacts.each do |contact|
        service = new(contact)
        result = service.sync_to_salesforce

        if result[:success]
          results[:synced] += 1
        else
          results[:failed] += 1
          results[:errors] << { contact_id: contact.id, error: result[:error] }
        end

        sleep(0.1) # Rate limiting
      end

      results
    end

    private

    def valid_access_token?
      return false unless @credentials.salesforce_access_token.present?
      return false unless @credentials.salesforce_instance_url.present?
      
      # Check if token is expired (with 5 minute buffer)
      if @credentials.salesforce_token_expires_at.present?
        if @credentials.salesforce_token_expires_at <= 5.minutes.from_now
          # Token expired or expiring soon - attempt refresh
          return refresh_access_token
        end
      end
      
      true
    end

    def refresh_access_token
      return false unless @credentials.salesforce_refresh_token.present?
      
      Rails.logger.info "Refreshing Salesforce access token"
      
      begin
        uri = URI('https://login.salesforce.com/services/oauth2/token')
        request = Net::HTTP::Post.new(uri)
        request.set_form_data(
          grant_type: 'refresh_token',
          client_id: @credentials.salesforce_client_id,
          client_secret: @credentials.salesforce_client_secret,
          refresh_token: @credentials.salesforce_refresh_token
        )

        response = Net::HTTP.start(uri.hostname, uri.port,
                                    use_ssl: true,
                                    read_timeout: 15,
                                    open_timeout: 10) do |http|
          http.request(request)
        end

        if response.code.to_i == 200
          data = JSON.parse(response.body)
          
          # Salesforce access tokens typically expire in 2 hours
          expires_at = Time.current + 2.hours
          
          @credentials.update!(
            salesforce_access_token: data['access_token'],
            salesforce_instance_url: data['instance_url'] || @credentials.salesforce_instance_url,
            salesforce_token_expires_at: expires_at
          )
          
          Rails.logger.info "Salesforce token refreshed successfully"
          true
        else
          error_data = JSON.parse(response.body) rescue {}
          Rails.logger.error "Salesforce token refresh failed: #{error_data['error_description'] || response.code}"
          false
        end
      rescue StandardError => e
        Rails.logger.error "Salesforce token refresh error: #{e.message}"
        false
      end
    end

    def create_salesforce_contact
      uri = URI("#{@credentials.salesforce_instance_url}/services/data/#{SALESFORCE_API_VERSION}/sobjects/Contact")
      body = build_salesforce_payload

      response = HttpClient.post(uri, body: body, circuit_name: 'salesforce-api') do |request|
        request['Authorization'] = "Bearer #{@credentials.salesforce_access_token}"
      end

      if response.code.to_i == 201
        data = JSON.parse(response.body)
        { success: true, id: data['id'], action: 'created' }
      else
        error_data = JSON.parse(response.body) rescue {}
        { success: false, error: error_data['message'] || 'Salesforce create error' }
      end
    rescue HttpClient::TimeoutError, HttpClient::CircuitOpenError => e
      { success: false, error: "Service unavailable: #{e.message}" }
    end

    def update_salesforce_contact
      uri = URI("#{@credentials.salesforce_instance_url}/services/data/#{SALESFORCE_API_VERSION}/sobjects/Contact/#{@contact.salesforce_id}")
      body = build_salesforce_payload

      response = HttpClient.patch(uri, body: body, circuit_name: 'salesforce-api') do |request|
        request['Authorization'] = "Bearer #{@credentials.salesforce_access_token}"
      end

      if response.code.to_i == 204
        { success: true, id: @contact.salesforce_id, action: 'updated' }
      else
        error_data = JSON.parse(response.body) rescue {}
        { success: false, error: error_data['message'] || 'Salesforce update error' }
      end
    rescue HttpClient::TimeoutError, HttpClient::CircuitOpenError => e
      { success: false, error: "Service unavailable: #{e.message}" }
    end

    def build_salesforce_payload
      payload = {}

      # Basic fields
      payload['FirstName'] = @contact.first_name if @contact.first_name.present?
      payload['LastName'] = @contact.last_name || 'Unknown'
      payload['Phone'] = @contact.formatted_phone_number if @contact.formatted_phone_number.present?
      payload['Email'] = @contact.email if @contact.email.present?
      payload['Title'] = @contact.position if @contact.position.present?

      # Company fields (if business)
      if @contact.business?
        payload['Account'] = { Name: @contact.business_name } if @contact.business_name.present?
      end

      # Address fields
      if @contact.has_full_address?
        payload['MailingStreet'] = @contact.consumer_address
        payload['MailingCity'] = @contact.consumer_city
        payload['MailingState'] = @contact.consumer_state
        payload['MailingPostalCode'] = @contact.consumer_postal_code
        payload['MailingCountry'] = @contact.consumer_country || 'US'
      end

      # Custom fields (you can customize these)
      payload['Description'] = "Data quality score: #{@contact.data_quality_score}%"
      payload['LeadSource'] = 'Twilio Bulk Lookup'

      payload
    end

    def log_api_usage(params)
      ApiUsageLog.log_api_call(
        contact_id: @contact.id,
        provider: 'salesforce',
        service: params[:service],
        status: params[:status],
        response_time_ms: params[:response_time_ms],
        error_message: params[:error_message],
        requested_at: Time.current,
        cost: 0 # Salesforce doesn't charge per API call in most plans
      )
    end
  end
end
