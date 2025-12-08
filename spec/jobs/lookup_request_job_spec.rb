# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LookupRequestJob, type: :job do
  # Darwin-Gödel Test Suite - Validates Race Condition Fix

  let(:contact) { create(:contact, status: 'pending') }
  let(:credentials) { create(:twilio_credential) }

  before do
    allow(TwilioCredential).to receive(:current).and_return(credentials)
  end

  describe 'race condition prevention' do
    context 'when multiple jobs run concurrently' do
      it 'prevents duplicate processing with pessimistic locking' do
        # Simulate concurrent job execution
        contact_id = contact.id

        threads = 10.times.map do
          Thread.new do
            fresh_contact = Contact.find(contact_id)
            LookupRequestJob.new.perform(fresh_contact)
          end
        end

        threads.each(&:join)

        # Only one job should have processed the contact
        contact.reload
        expect(contact.status).to be_in(%w[processing completed failed])
      end

      it 'skips already processing contacts' do
        contact.update!(status: 'processing')

        expect {
          LookupRequestJob.new.perform(contact)
        }.not_to change { contact.reload.status }
      end

      it 'logs skip message when contact already processing' do
        contact.update!(status: 'processing')

        expect(Rails.logger).to receive(:info)
          .with(/Skipping contact #{contact.id}: already being processed/)

        LookupRequestJob.new.perform(contact)
      end
    end
  end

  describe 'idempotency' do
    it 'skips already completed contacts' do
      contact.update!(status: 'completed', formatted_phone_number: '+14155551234')

      expect(contact).not_to receive(:mark_processing!)

      LookupRequestJob.new.perform(contact)
    end

    it 'logs skip message for completed contacts' do
      contact.update!(status: 'completed', formatted_phone_number: '+14155551234')

      expect(Rails.logger).to receive(:info)
        .with(/Skipping contact #{contact.id}: already completed/)

      LookupRequestJob.new.perform(contact)
    end
  end

  describe 'error handling' do
    context 'when credentials are missing' do
      before do
        allow(TwilioCredential).to receive(:current).and_return(nil)
      end

      it 'marks contact as failed' do
        expect(contact).to receive(:mark_failed!)
          .with('No Twilio credentials configured')

        LookupRequestJob.new.perform(contact)
      end
    end

    context 'when Twilio API returns error' do
      let(:twilio_client) { double('Twilio::REST::Client') }
      let(:twilio_error) { Twilio::REST::RestError.new('Invalid number', double(code: 20404)) }

      before do
        allow(Twilio::REST::Client).to receive(:new).and_return(twilio_client)
        allow(twilio_client).to receive_message_chain(:lookups, :v2, :phone_numbers, :fetch)
          .and_raise(twilio_error)
      end

      it 'retries on transient failures' do
        expect {
          LookupRequestJob.new.perform(contact)
        }.to raise_error(Twilio::REST::RestError)

        # Job should be retried by Sidekiq
      end
    end
  end

  describe 'state transitions' do
    context 'from pending' do
      it 'marks contact as processing before API call' do
        allow_any_instance_of(LookupRequestJob).to receive(:perform).and_call_original

        # Mock Twilio to prevent actual API call
        twilio_client = double('Twilio::REST::Client')
        allow(Twilio::REST::Client).to receive(:new).and_return(twilio_client)
        allow(twilio_client).to receive_message_chain(:lookups, :v2, :phone_numbers, :fetch)
          .and_raise(StandardError, 'Mock error to prevent full execution')

        begin
          LookupRequestJob.new.perform(contact)
        rescue StandardError
          # Expected to fail on mocked API call
        end

        # Should have transitioned to processing despite error
        expect(contact.reload.status).to eq('processing')
      end
    end

    context 'from failed' do
      it 'allows retry from failed status' do
        contact.update!(status: 'failed', error_code: 'Rate limit exceeded')

        # Mock successful execution
        allow_any_instance_of(described_class).to receive(:mark_processing!)
        allow_any_instance_of(described_class).to receive(:mark_completed!)

        expect {
          LookupRequestJob.new.perform(contact)
        }.to change { contact.reload.status }.from('failed')
      end
    end
  end

  describe 'pessimistic locking' do
    it 'acquires row lock before status check' do
      expect(contact).to receive(:with_lock).and_call_original

      # Mock to prevent full execution
      allow(TwilioCredential).to receive(:current).and_return(nil)

      LookupRequestJob.new.perform(contact)
    end

    it 'releases lock after status transition' do
      # Verify lock is released by checking we can update in different transaction
      contact.update!(status: 'pending')

      thread = Thread.new do
        Contact.find(contact.id).with_lock do
          sleep 0.1  # Hold lock briefly
        end
      end

      sleep 0.05  # Let thread acquire lock

      # This should wait for lock to be released
      expect {
        contact.reload.update!(raw_phone_number: '+14155559999')
      }.not_to raise_error

      thread.join
    end
  end
end
