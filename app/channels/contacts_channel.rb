# frozen_string_literal: true

# ActionCable channel for real-time contact table updates
# Broadcasts individual contact row changes for live table updates
class ContactsChannel < ApplicationCable::Channel
  def subscribed
    stream_from 'contacts_updates'
  end

  def unsubscribed
    # Cleanup when channel is unsubscribed
  end
end
