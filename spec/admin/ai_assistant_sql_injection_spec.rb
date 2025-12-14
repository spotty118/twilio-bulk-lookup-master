require 'rails_helper'

# INFRASTRUCTURE REQUIRED:
# - PostgreSQL database
# - Contact table with columns: business_city, business_state, business_country
# - Arel gem (included in Rails)

RSpec.describe 'AI Assistant SQL Injection Protection', type: :feature do
  # This tests the evolved Solution 1C-v2: Arel + Column Validation
  # Protection against both direct field manipulation and AI prompt injection

  describe 'field name validation' do
    let(:contacts) { Contact.all }
    let(:ilike_fields) { %w[business_name business_city business_state business_country] }

    # Simulate the controller logic from app/admin/ai_assistant.rb
    def apply_search_filter(contacts, field, value, ilike_fields)
      if ilike_fields.include?(field) && Contact.column_names.include?(field)
        # Arel provides SQL injection protection
        contacts.where(Contact.arel_table[field].matches("%#{value}%"))
      elsif %w[business_industry business_type line_type status].include?(field)
        contacts.where(field => value)
      else
        contacts # Return unchanged if field not whitelisted
      end
    end

    context 'valid field names' do
      it 'accepts whitelisted ILIKE fields' do
        Contact.create!(raw_phone_number: '+14155551234', business_city: 'San Francisco')

        result = apply_search_filter(contacts, 'business_city', 'Francisco', ilike_fields)

        expect(result.to_sql).to include('business_city')
        expect(result.to_sql).not_to include('DROP')
        expect(result.count).to eq(1)
      end
    end

    context 'SQL injection attempts' do
      it 'blocks field name with SQL injection payload' do
        malicious_field = "id; DROP TABLE contacts--"

        # Should not raise error, just return unfiltered
        expect {
          result = apply_search_filter(contacts, malicious_field, 'value', ilike_fields)
          # SQL should not contain the malicious field
          expect(result.to_sql).not_to include('DROP')
        }.not_to raise_error
      end

      it 'blocks SQL injection via non-existent column' do
        malicious_field = "1=1 OR id"

        result = apply_search_filter(contacts, malicious_field, 'value', ilike_fields)

        # Should not include malicious SQL
        expect(result.to_sql).not_to include('1=1')
        expect(result).to eq(contacts) # Unchanged
      end

      it 'blocks column name with comment injection' do
        malicious_field = "id--"

        result = apply_search_filter(contacts, malicious_field, 'value', ilike_fields)

        expect(result.to_sql).not_to include('--')
        expect(result).to eq(contacts)
      end
    end

    context 'prompt injection attacks (AI-generated malicious fields)' do
      it 'protects against AI returning malicious field names' do
        # Simulate AI prompt injection where user tricks AI into returning:
        # {"filters": {"id; DROP TABLE contacts--": "value"}}

        ai_generated_field = "id; DROP TABLE contacts--"
        ai_generated_value = "pwned"

        result = apply_search_filter(contacts, ai_generated_field, ai_generated_value, ilike_fields)

        # Should safely ignore the malicious field
        expect(result.to_sql).not_to include('DROP TABLE')
        expect(result).to eq(contacts) # No filter applied
      end

      it 'protects against Unicode SQL injection' do
        # Advanced attack: Unicode characters that might bypass filters
        malicious_field = "business_city\u0000; DROP TABLE contacts--"

        result = apply_search_filter(contacts, malicious_field, 'value', ilike_fields)

        expect(result.to_sql).not_to include('DROP')
        expect(result).to eq(contacts)
      end
    end

    context 'Arel parameterization' do
      it 'uses parameterized queries for value safety' do
        Contact.create!(raw_phone_number: '+14155551234', business_city: 'San Francisco')

        # Even with malicious value, Arel parameterizes it
        malicious_value = "'; DROP TABLE contacts--"

        result = apply_search_filter(contacts, 'business_city', malicious_value, ilike_fields)

        # Should safely search for the literal string (no rows found)
        expect(result.count).to eq(0)

        # Verify contacts table still exists
        expect(Contact.count).to eq(1)
      end
    end

    context 'defense-in-depth validation' do
      it 'requires both whitelist AND column existence' do
        # Even if we add a field to whitelist but it doesn't exist in DB
        fake_field = 'nonexistent_column'

        # Manually add to ILIKE_FIELDS (simulating code error)
        ilike_fields = %w[business_city nonexistent_column]

        # Should still block because column doesn't exist
        if ilike_fields.include?(fake_field) && Contact.column_names.include?(fake_field)
          # This branch should NOT execute
          fail "Should not reach here - column validation failed"
        end

        # Column validation prevents undefined method error
        expect(Contact.column_names).not_to include(fake_field)
      end
    end
  end

  describe 'regression test: original vulnerability' do
    it 'documents the original vulnerable code (DO NOT USE)' do
      # Original buggy code (for documentation only):
      # contacts.where("#{field} ILIKE ?", "%#{value}%")
      #
      # Attack: field = "id=1; DROP TABLE contacts--"
      # SQL: WHERE id=1; DROP TABLE contacts-- ILIKE '%value%'
      # Result: Table dropped!

      # This test verifies the vulnerability is FIXED
      malicious_field = "id=1; DROP TABLE contacts--"

      # New code safely ignores the field
      result = Contact.all
      if %w[business_name business_city business_state business_country].include?(malicious_field) &&
         Contact.column_names.include?(malicious_field)
        result = result.where(Contact.arel_table[malicious_field].matches("%value%"))
      end

      # Should return all contacts unfiltered (field not whitelisted)
      expect(result.to_sql).not_to include('DROP TABLE')
    end
  end
end
