class CrmSyncJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(contact_id, crm_type = nil)
    contact = Contact.find(contact_id)
    credentials = TwilioCredential.current

    return unless contact.crm_sync_enabled

    results = {}

    # Sync to Salesforce
    if (crm_type.nil? || crm_type == 'salesforce') && credentials.enable_salesforce_sync
      service = CrmSync::SalesforceService.new(contact)
      results[:salesforce] = service.sync_to_salesforce
    end

    # Sync to HubSpot
    if (crm_type.nil? || crm_type == 'hubspot') && credentials.enable_hubspot_sync
      service = CrmSync::HubspotService.new(contact)
      results[:hubspot] = service.sync_to_hubspot
    end

    # Sync to Pipedrive
    if (crm_type.nil? || crm_type == 'pipedrive') && credentials.enable_pipedrive_sync
      service = CrmSync::PipedriveService.new(contact)
      results[:pipedrive] = service.sync_to_pipedrive
    end

    Rails.logger.info "CRM sync completed for contact #{contact_id}: #{results}"
    results
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "Contact not found for CRM sync: #{contact_id}"
  rescue => e
    Rails.logger.error "CRM sync job failed for contact #{contact_id}: #{e.message}"
    raise
  end
end
