require 'net/http'
require 'json'

module CrmSync
  class PipedriveService
    def initialize(contact = nil)
      @contact = contact
      @credentials = TwilioCredential.current
    end

    # Sync contact to Pipedrive
    def sync_to_pipedrive
      return { success: false, error: 'Pipedrive sync not enabled' } unless @credentials&.enable_pipedrive_sync
      return { success: false, error: 'CRM sync disabled for this contact' } unless @contact.crm_sync_enabled
      return { success: false, error: 'No Pipedrive API key' } unless @credentials.pipedrive_api_key.present?
      return { success: false, error: 'No Pipedrive company domain configured' } unless @credentials.pipedrive_company_domain.present?

      start_time = Time.current

      begin
        if @contact.pipedrive_id.present?
          result = update_pipedrive_person
        else
          result = create_pipedrive_person
        end

        if result[:success]
          @contact.update!(
            pipedrive_id: result[:id],
            pipedrive_synced_at: Time.current,
            pipedrive_sync_status: 'synced',
            last_crm_sync_at: Time.current
          )

          log_api_usage(service: 'sync_contact', status: 'success', response_time_ms: ((Time.current - start_time) * 1000).to_i)
        else
          @contact.update!(
            pipedrive_sync_status: 'failed',
            crm_sync_errors: (@contact.crm_sync_errors || {}).merge(pipedrive: { error: result[:error], timestamp: Time.current })
          )

          log_api_usage(service: 'sync_contact', status: 'failed', error_message: result[:error], response_time_ms: ((Time.current - start_time) * 1000).to_i)
        end

        result
      rescue StandardError => e
        Rails.logger.error "Pipedrive sync error for contact #{@contact.id}: #{e.message}"
        { success: false, error: e.message }
      end
    end

    # Batch sync
    def self.batch_sync(contacts)
      results = { total: contacts.count, synced: 0, failed: 0, errors: [] }

      contacts.each do |contact|
        service = new(contact)
        result = service.sync_to_pipedrive

        if result[:success]
          results[:synced] += 1
        else
          results[:failed] += 1
          results[:errors] << { contact_id: contact.id, error: result[:error] }
        end

        sleep(0.1)
      end

      results
    end

    private

    def base_url
      company_domain = @credentials&.pipedrive_company_domain
      return nil if company_domain.blank?

      "https://#{company_domain}.pipedrive.com/api/v1"
    end

    def create_pipedrive_person
      uri = URI("#{base_url}/persons")
      body = build_pipedrive_payload

      response = HttpClient.post(uri, body: body, circuit_name: 'pipedrive-api') do |request|
        request['Authorization'] = "Bearer #{@credentials.pipedrive_api_key}"
      end

      if response.code.to_i == 201
        data = JSON.parse(response.body)
        { success: true, id: data.dig('data', 'id').to_s, action: 'created' }
      else
        error_data = JSON.parse(response.body) rescue {}
        { success: false, error: error_data['error'] || 'Pipedrive create error' }
      end
    rescue HttpClient::TimeoutError, HttpClient::CircuitOpenError => e
      { success: false, error: "Service unavailable: #{e.message}" }
    end

    def update_pipedrive_person
      uri = URI("#{base_url}/persons/#{@contact.pipedrive_id}")
      body = build_pipedrive_payload

      response = HttpClient.put(uri, body: body, circuit_name: 'pipedrive-api') do |request|
        request['Authorization'] = "Bearer #{@credentials.pipedrive_api_key}"
      end

      if response.code.to_i == 200
        { success: true, id: @contact.pipedrive_id, action: 'updated' }
      else
        error_data = JSON.parse(response.body) rescue {}
        { success: false, error: error_data['error'] || 'Pipedrive update error' }
      end
    rescue HttpClient::TimeoutError, HttpClient::CircuitOpenError => e
      { success: false, error: "Service unavailable: #{e.message}" }
    end

    def build_pipedrive_payload
      payload = {}

      payload['name'] = @contact.full_name || @contact.business_name || 'Unknown'
      payload['email'] = [{ value: @contact.email, primary: true }] if @contact.email.present?
      payload['phone'] = [{ value: @contact.formatted_phone_number, primary: true }] if @contact.formatted_phone_number.present?
      payload['org_id'] = find_or_create_organization if @contact.business_name.present?

      payload
    end

    def find_or_create_organization
      # This is a simplified version - in production you'd search first
      return nil unless @contact.business_name.present?

      uri = URI("#{base_url}/organizations")
      body = { name: @contact.business_name }

      response = HttpClient.post(uri, body: body, circuit_name: 'pipedrive-api') do |request|
        request['Authorization'] = "Bearer #{@credentials.pipedrive_api_key}"
      end

      if response.code.to_i == 201
        data = JSON.parse(response.body)
        data.dig('data', 'id')
      else
        nil
      end
    rescue StandardError => e
      nil
    end

    def log_api_usage(params)
      ApiUsageLog.log_api_call(
        contact_id: @contact.id,
        provider: 'pipedrive',
        service: params[:service],
        status: params[:status],
        response_time_ms: params[:response_time_ms],
        error_message: params[:error_message],
        requested_at: Time.current,
        cost: 0
      )
    end
  end
end
