require 'net/http'
require 'json'

module CrmSync
  class HubspotService
    HUBSPOT_API_URL = 'https://api.hubapi.com'

    def initialize(contact = nil)
      @contact = contact
      @credentials = TwilioCredential.current
    end

    # Sync contact to HubSpot
    def sync_to_hubspot
      return { success: false, error: 'HubSpot sync not enabled' } unless @credentials&.enable_hubspot_sync
      return { success: false, error: 'CRM sync disabled for this contact' } unless @contact.crm_sync_enabled
      return { success: false, error: 'No HubSpot API key' } unless @credentials.hubspot_api_key.present?

      start_time = Time.current

      begin
        if @contact.hubspot_id.present?
          result = update_hubspot_contact
        else
          result = create_hubspot_contact
        end

        if result[:success]
          @contact.update!(
            hubspot_id: result[:id],
            hubspot_synced_at: Time.current,
            hubspot_sync_status: 'synced',
            last_crm_sync_at: Time.current
          )

          log_api_usage(service: 'sync_contact', status: 'success', response_time_ms: ((Time.current - start_time) * 1000).to_i)
        else
          @contact.update!(
            hubspot_sync_status: 'failed',
            crm_sync_errors: (@contact.crm_sync_errors || {}).merge(hubspot: { error: result[:error], timestamp: Time.current })
          )

          log_api_usage(service: 'sync_contact', status: 'failed', error_message: result[:error], response_time_ms: ((Time.current - start_time) * 1000).to_i)
        end

        result
      rescue => e
        Rails.logger.error "HubSpot sync error for contact #{@contact.id}: #{e.message}"
        { success: false, error: e.message }
      end
    end

    # Batch sync
    def self.batch_sync(contacts)
      results = { total: contacts.count, synced: 0, failed: 0, errors: [] }

      contacts.each do |contact|
        service = new(contact)
        result = service.sync_to_hubspot

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

    def create_hubspot_contact
      uri = URI("#{HUBSPOT_API_URL}/crm/v3/objects/contacts")
      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Bearer #{@credentials.hubspot_api_key}"
      request['Content-Type'] = 'application/json'
      request.body = { properties: build_hubspot_properties }.to_json

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end

      if response.code.to_i == 201
        data = JSON.parse(response.body)
        { success: true, id: data['id'], action: 'created' }
      else
        error_data = JSON.parse(response.body) rescue {}
        { success: false, error: error_data['message'] || 'HubSpot create error' }
      end
    end

    def update_hubspot_contact
      uri = URI("#{HUBSPOT_API_URL}/crm/v3/objects/contacts/#{@contact.hubspot_id}")
      request = Net::HTTP::Patch.new(uri)
      request['Authorization'] = "Bearer #{@credentials.hubspot_api_key}"
      request['Content-Type'] = 'application/json'
      request.body = { properties: build_hubspot_properties }.to_json

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end

      if response.code.to_i == 200
        { success: true, id: @contact.hubspot_id, action: 'updated' }
      else
        error_data = JSON.parse(response.body) rescue {}
        { success: false, error: error_data['message'] || 'HubSpot update error' }
      end
    end

    def build_hubspot_properties
      properties = {}

      properties['firstname'] = @contact.first_name if @contact.first_name.present?
      properties['lastname'] = @contact.last_name if @contact.last_name.present?
      properties['email'] = @contact.email if @contact.email.present?
      properties['phone'] = @contact.formatted_phone_number if @contact.formatted_phone_number.present?
      properties['jobtitle'] = @contact.position if @contact.position.present?
      properties['company'] = @contact.business_name if @contact.business_name.present?
      properties['city'] = @contact.business_city || @contact.consumer_city if @contact.business_city.present? || @contact.consumer_city.present?
      properties['state'] = @contact.business_state || @contact.consumer_state if @contact.business_state.present? || @contact.consumer_state.present?
      properties['website'] = @contact.business_website if @contact.business_website.present?
      properties['hs_lead_status'] = 'NEW'
      properties['lifecyclestage'] = 'lead'

      properties
    end

    def log_api_usage(params)
      ApiUsageLog.log_api_call(
        contact_id: @contact.id,
        provider: 'hubspot',
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
