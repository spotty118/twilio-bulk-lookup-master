require 'rails_helper'

# INFRASTRUCTURE REQUIRED:
# - PostgreSQL with unique partial index support
# - Run migration: rails db:migrate
# - Test database: RAILS_ENV=test rails db:setup

RSpec.describe TwilioCredential, type: :model do
  # Clear cache before each test to ensure isolation
  before(:each) do
    Rails.cache.clear
  end

  describe 'singleton enforcement' do
    # Requirements: 4.1, 4.2
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
    # Requirements: 4.1
    it 'returns the singleton instance' do
      credential = create(:twilio_credential, is_singleton: true)

      result = TwilioCredential.current

      expect(result).to eq(credential)
      expect(result.id).to eq(credential.id)
    end

    it 'returns nil when no singleton exists' do
      result = TwilioCredential.current

      expect(result).to be_nil
    end

    it 'returns only the singleton record, not non-singleton records' do
      non_singleton = create(:twilio_credential, is_singleton: false)
      singleton = create(:twilio_credential, is_singleton: true)

      result = TwilioCredential.current

      expect(result).to eq(singleton)
      expect(result).not_to eq(non_singleton)
    end
  end

  describe 'cache behavior' do
    # Requirements: 4.3, 4.4
    # Use memory store for cache tests since test env uses null_store
    around(:each) do |example|
      original_cache = Rails.cache
      Rails.cache = ActiveSupport::Cache::MemoryStore.new
      example.run
      Rails.cache = original_cache
    end

    describe 'cached results within TTL' do
      it 'returns cached results on subsequent calls' do
        credential = create(:twilio_credential, is_singleton: true)

        # First call populates cache
        result1 = TwilioCredential.current

        # Second call should return same result from cache
        result2 = TwilioCredential.current

        expect(result1).to eq(credential)
        expect(result2).to eq(credential)
        expect(result1.id).to eq(result2.id)
      end

      it 'uses cache key for singleton lookup' do
        credential = create(:twilio_credential, is_singleton: true)

        # First call to populate cache
        TwilioCredential.current

        # Verify cache was populated with correct key
        cache_key = 'twilio_credential_singleton'
        cached_value = Rails.cache.read(cache_key)
        expect(cached_value).to eq(credential)
      end
    end

    describe 'cache invalidation on update' do
      it 'invalidates cache when singleton is updated' do
        credential = create(:twilio_credential, is_singleton: true, enable_caller_name: false)

        # Populate cache
        cached_result = TwilioCredential.current
        expect(cached_result.enable_caller_name).to be false

        # Update the credential
        credential.update!(enable_caller_name: true)

        # Cache should be invalidated, fresh data returned
        fresh_result = TwilioCredential.current
        expect(fresh_result.enable_caller_name).to be true
      end

      it 'invalidates cache when singleton is destroyed' do
        credential = create(:twilio_credential, is_singleton: true)

        # Populate cache
        TwilioCredential.current

        # Destroy the credential
        credential.destroy!

        # Cache should be invalidated, nil returned
        result = TwilioCredential.current
        expect(result).to be_nil
      end

      it 'does not invalidate cache for non-singleton record updates' do
        singleton = create(:twilio_credential, is_singleton: true)
        non_singleton = create(:twilio_credential, is_singleton: false)

        # Populate cache with singleton
        TwilioCredential.current

        # Update non-singleton - should not affect singleton cache
        non_singleton.update!(enable_caller_name: true)

        # Singleton should still be returned from cache (same record)
        result = TwilioCredential.current
        expect(result).to eq(singleton)
      end
    end
  end

  describe 'validations' do
    it 'requires account_sid' do
      credential = build(:twilio_credential, account_sid: nil)
      expect(credential).not_to be_valid
      expect(credential.errors[:account_sid]).to include("can't be blank")
    end

    it 'requires auth_token' do
      credential = build(:twilio_credential, auth_token: nil)
      expect(credential).not_to be_valid
      expect(credential.errors[:auth_token]).to include("can't be blank")
    end

    it 'validates account_sid format' do
      credential = build(:twilio_credential, account_sid: 'invalid')
      expect(credential).not_to be_valid
      expect(credential.errors[:account_sid]).to include(/must be a valid Twilio Account SID/)
    end

    it 'validates auth_token format' do
      credential = build(:twilio_credential, auth_token: 'short')
      expect(credential).not_to be_valid
      expect(credential.errors[:auth_token]).to include(/must be a valid Twilio Auth Token/)
    end

    it 'accepts valid account_sid format' do
      credential = build(:twilio_credential, account_sid: 'AC' + 'a' * 32)
      credential.valid?
      expect(credential.errors[:account_sid]).to be_empty
    end

    it 'accepts valid auth_token format' do
      credential = build(:twilio_credential, auth_token: 'a' * 32)
      credential.valid?
      expect(credential.errors[:auth_token]).to be_empty
    end
  end

  describe '#data_packages' do
    it 'returns empty string when no packages enabled' do
      credential = build(:twilio_credential, :with_no_packages)
      expect(credential.data_packages).to eq('')
    end

    it 'returns comma-separated list of enabled packages' do
      credential = build(:twilio_credential, :with_all_packages)
      packages = credential.data_packages.split(',')

      expect(packages).to include('line_type_intelligence')
      expect(packages).to include('caller_name')
      expect(packages).to include('sms_pumping_risk')
      expect(packages).to include('sim_swap')
      expect(packages).to include('reassigned_number')
    end

    it 'returns only enabled packages' do
      credential = build(:twilio_credential, :with_minimal_packages)
      expect(credential.data_packages).to eq('line_type_intelligence')
    end
  end

  describe '#data_packages_enabled?' do
    it 'returns false when no packages enabled' do
      credential = build(:twilio_credential, :with_no_packages)
      expect(credential.data_packages_enabled?).to be false
    end

    it 'returns true when at least one package enabled' do
      credential = build(:twilio_credential, :with_minimal_packages)
      expect(credential.data_packages_enabled?).to be true
    end
  end
end
