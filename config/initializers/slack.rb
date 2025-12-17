# frozen_string_literal: true

require 'slack-notifier'

# Initialize Slack Notifier if webhook URL is present
SLACK_NOTIFIER = if ENV['SLACK_WEBHOOK_URL'].present?
                   Slack::Notifier.new ENV['SLACK_WEBHOOK_URL'] do
                     defaults channel: '#alerts',
                              username: 'TwilioBulkLookup'
                   end
                 else
                   # Null object pattern to prevent errors if not configured
                   Class.new do
                     def ping(message) = Rails.logger.info("[Slack] #{message}")
                   end.new
                 end
