require 'rails_helper'

# INFRASTRUCTURE REQUIRED:
# - PostgreSQL with unique partial index support
# - Run migration: rails db:migrate
# - Test database: RAILS_ENV=test rails db:setup

RSpec.describe TwilioCredential, type: :model do
  describe 'singleton enforcement' do
    context 'database-level constraint' do
      it 'prevents creating second record with is_singleton=true' do
        # Create first record
        first = TwilioCredential.create!(
          account_sid: 'AC' + 'a' * 32,
          auth_token: 'b' * 32,
          is_singleton: true
        )

        # Attempt to create second record should fail at DB level
        second = TwilioCredential.new(
          account_sid: 'AC' + 'c' * 32,
          auth_token: 'd' * 32,
          is_singleton: true
        )

        expect { second.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
      end

      it 'allows creating records with is_singleton=false' do
        # This supports soft-delete pattern or archiving old credentials
        first = TwilioCredential.create!(
          account_sid: 'AC' + 'a' * 32,
          auth_token: 'b' * 32,
          is_singleton: true
        )

        archived = TwilioCredential.create!(
          account_sid: 'AC' + 'e' * 32,
          auth_token: 'f' * 32,
          is_singleton: false
        )

        expect(archived).to be_persisted
      end
    end

    context 'concurrent creation race condition' do
      it 'prevents race condition with concurrent requests', :concurrency do
        # Simulate two simultaneous create attempts
        threads = 2.times.map do |i|
          Thread.new do
            begin
              TwilioCredential.create!(
                account_sid: "AC#{i}#{'x' * 31}",
                auth_token: "#{i}#{'y' * 31}",
                is_singleton: true
              )
            rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
              nil
            end
          end
        end

        results = threads.map(&:value).compact

        # Exactly one should succeed
        expect(results.count).to eq(1)
        expect(TwilioCredential.where(is_singleton: true).count).to eq(1)
      end
    end

    context 'model-level validation' do
      it 'provides user-friendly error before hitting database' do
        TwilioCredential.create!(
          account_sid: 'AC' + 'a' * 32,
          auth_token: 'b' * 32,
          is_singleton: true
        )

        duplicate = TwilioCredential.new(
          account_sid: 'AC' + 'c' * 32,
          auth_token: 'd' * 32,
          is_singleton: true
        )

        expect(duplicate.valid?).to be false
        expect(duplicate.errors[:base]).to include(/Only one Twilio credential/)
      end
    end
  end

  describe '.current' do
    it 'caches credentials for 1 hour' do
      credential = TwilioCredential.create!(
        account_sid: 'AC' + 'a' * 32,
        auth_token: 'b' * 32
      )

      # First call
      result1 = TwilioCredential.current

      # Should not hit database on second call
      expect(TwilioCredential).not_to receive(:first)
      result2 = TwilioCredential.current

      expect(result1).to eq(credential)
      expect(result2).to eq(credential)
    end
  end
end
