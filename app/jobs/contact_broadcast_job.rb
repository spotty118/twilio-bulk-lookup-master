# frozen_string_literal: true

# Broadcasts individual contact updates for live table refresh
# This job renders the contact row HTML and sends it via ActionCable
class ContactBroadcastJob < ApplicationJob
  queue_as :default

  def perform(contact_id)
    contact = Contact.find_by(id: contact_id)
    return unless contact

    # Broadcast the updated contact data as JSON
    # The JavaScript will update the row in place
    ActionCable.server.broadcast('contacts_updates', {
      action: 'update',
      contact_id: contact.id,
      status: contact.status,
      status_class: contact.status,
      device_type: contact.device_type,
      rpv_status: contact.rpv_status,
      rpv_status_class: rpv_status_class(contact.rpv_status),
      carrier_name: contact.carrier_name,
      risk_level: contact.sms_pumping_risk_level,
      risk_class: risk_class(contact.sms_pumping_risk_level),
      is_business: contact.is_business,
      business_name: contact.business_name,
      formatted_phone: contact.formatted_phone_number
    })
  rescue StandardError => e
    Rails.logger.warn("Contact broadcast failed for #{contact_id}: #{e.message}")
  end

  private

  def rpv_status_class(status)
    return nil unless status

    case status.downcase
    when 'connected' then 'ok'
    when 'disconnected' then 'error'
    else 'warning'
    end
  end

  def risk_class(level)
    return nil unless level

    case level
    when 'high' then 'error'
    when 'medium' then 'warning'
    when 'low' then 'ok'
    end
  end
end
