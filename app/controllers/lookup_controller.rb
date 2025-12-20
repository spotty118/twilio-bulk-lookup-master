require 'twilio-ruby'

class LookupController < ApplicationController
  # Prevent unauthorized access
  before_action :authenticate_admin_user!

  # Limit batch size to prevent overwhelming Sidekiq queue
  MAX_BATCH_SIZE = 1000

  def run
    # Count contacts to process
    contacts_to_process = Contact.not_processed

    if contacts_to_process.empty?
      redirect_to admin_dashboard_path, alert: 'No contacts to process. All contacts have been looked up.'
      return
    end

    # Queue only pending/failed contacts for processing (with batch limit)
    queued_count = 0
    total_pending = contacts_to_process.count

    contacts_to_process.limit(MAX_BATCH_SIZE).each do |contact|
      # Skip if already processing or completed
      next if contact.status == 'processing' || contact.status == 'completed'

      LookupRequestJob.perform_later(contact.id)
      queued_count += 1
    end
    
    Rails.logger.info("Queued #{queued_count} contacts for lookup processing (#{total_pending} total pending)")

    notice_message = if total_pending > MAX_BATCH_SIZE
                       "Successfully queued #{queued_count} contacts for lookup (#{total_pending - queued_count} remaining). Run again to process more."
                     else
                       "Successfully queued #{queued_count} contacts for lookup. Processing will continue in the background."
                     end

    redirect_to admin_contacts_path, notice: notice_message
  end
end
