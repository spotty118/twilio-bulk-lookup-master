require 'twilio-ruby'

class LookupController < ApplicationController
  # Prevent unauthorized access
  before_action :authenticate_admin_user!
  
  def run
    # Count contacts to process
    contacts_to_process = Contact.not_processed
    
    if contacts_to_process.empty?
      redirect_to admin_dashboard_path, alert: 'No contacts to process. All contacts have been looked up.'
      return
    end
    
    # Queue only pending/failed contacts for processing
    queued_count = 0
    contacts_to_process.find_each do |contact|
      # Skip if already processing or completed
      next if contact.status == 'processing' || contact.status == 'completed'
      
      LookupRequestJob.perform_later(contact)
      queued_count += 1
    end
    
    Rails.logger.info("Queued #{queued_count} contacts for lookup processing")
    
    redirect_to admin_contacts_path,
                notice: "Successfully queued #{queued_count} contacts for lookup. Processing will continue in the background."
  end
end
