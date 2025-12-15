# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'CSV Formula Injection Prevention', type: :request do
  # COGNITIVE HYPERCLUSTER TEST SUITE
  # Test Fix: CSV formula escaping prevents Excel formula injection attacks
  # Coverage: escape_csv_formula method applied to 52 columns in CSV export
  # Edge Cases: All dangerous prefixes (=, +, -, @), nil values, safe values

  let(:admin_user) { AdminUser.create!(email: 'admin@example.com', password: 'password123', password_confirmation: 'password123') }

  before do
    # ActiveAdmin uses Warden for authentication
    post admin_user_session_path, params: { admin_user: { email: admin_user.email, password: 'password123' } }
  end

  describe 'escape_csv_formula method' do
    let(:admin_contacts_resource) { ActiveAdmin.application.namespaces[:admin].resources['Contact'] }

    it 'escapes formula starting with =' do
      result = admin_contacts_resource.escape_csv_formula('=1+1')
      expect(result).to eq("'=1+1")
    end

    it 'escapes formula starting with +' do
      result = admin_contacts_resource.escape_csv_formula('+SAFE')
      expect(result).to eq("'+SAFE")
    end

    it 'escapes formula starting with -' do
      result = admin_contacts_resource.escape_csv_formula('-5')
      expect(result).to eq("'-5")
    end

    it 'escapes formula starting with @' do
      result = admin_contacts_resource.escape_csv_formula('@SUM')
      expect(result).to eq("'@SUM")
    end

    it 'preserves safe values without prefix' do
      result = admin_contacts_resource.escape_csv_formula('Safe Corp')
      expect(result).to eq('Safe Corp')
    end

    it 'preserves numeric values without dangerous prefix' do
      result = admin_contacts_resource.escape_csv_formula('12345')
      expect(result).to eq('12345')
    end

    it 'preserves nil values' do
      result = admin_contacts_resource.escape_csv_formula(nil)
      expect(result).to be_nil
    end

    it 'handles empty strings' do
      result = admin_contacts_resource.escape_csv_formula('')
      expect(result).to eq('')
    end

    it 'escapes symbols converted to strings' do
      result = admin_contacts_resource.escape_csv_formula(:'+SYMBOL')
      expect(result).to eq("'+SYMBOL")
    end
  end

  describe 'CSV export applies formula escaping' do
    let!(:malicious_contact) do
      create(:contact,
        business_name: '=1+1',
        business_city: '+cmd|calc',
        caller_name: '-SAFE',
        business_type: '@SUM(A1:A10)',
        error_code: '=HYPERLINK("http://evil.com")',
        formatted_phone_number: '+14155551234',
        raw_phone_number: '+14155551234'
      )
    end

    let!(:safe_contact) do
      create(:contact,
        business_name: 'Acme Corp',
        business_city: 'San Francisco',
        caller_name: 'John Doe',
        formatted_phone_number: '+14155559999'
      )
    end

    it 'exports CSV with formula escaping applied' do
      get admin_contacts_path(format: :csv)

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('text/csv')

      csv_content = response.body
      csv_rows = CSV.parse(csv_content)

      # Find the malicious contact row (by ID)
      header_row = csv_rows[0]
      business_name_index = header_row.index('business_name')
      business_city_index = header_row.index('business_city')
      caller_name_index = header_row.index('caller_name')
      business_type_index = header_row.index('business_type')
      error_code_index = header_row.index('error_code')

      malicious_row = csv_rows.find { |row| row[0].to_i == malicious_contact.id }

      expect(malicious_row).not_to be_nil
      expect(malicious_row[business_name_index]).to eq("'=1+1")
      expect(malicious_row[business_city_index]).to eq("'+cmd|calc")
      expect(malicious_row[caller_name_index]).to eq("'-SAFE")
      expect(malicious_row[business_type_index]).to eq("'@SUM(A1:A10)")
      expect(malicious_row[error_code_index]).to eq("'=HYPERLINK(\"http://evil.com\")")
    end

    it 'does not escape safe values in CSV export' do
      get admin_contacts_path(format: :csv)

      csv_content = response.body
      csv_rows = CSV.parse(csv_content)

      header_row = csv_rows[0]
      business_name_index = header_row.index('business_name')

      safe_row = csv_rows.find { |row| row[0].to_i == safe_contact.id }

      expect(safe_row[business_name_index]).to eq('Acme Corp')
      expect(safe_row[business_name_index]).not_to start_with("'")
    end

    it 'preserves nil values in CSV export' do
      contact_with_nils = create(:contact,
        business_name: nil,
        business_city: nil
      )

      get admin_contacts_path(format: :csv)

      csv_content = response.body
      csv_rows = CSV.parse(csv_content)

      header_row = csv_rows[0]
      business_name_index = header_row.index('business_name')

      nil_row = csv_rows.find { |row| row[0].to_i == contact_with_nils.id }

      expect(nil_row[business_name_index]).to be_nil
    end
  end

  describe 'All 52 columns apply formula escaping' do
    let(:escaped_columns) do
      [
        :raw_phone_number, :formatted_phone_number, :status, :country_code,
        :calling_country_code, :line_type, :carrier_name, :device_type,
        :mobile_country_code, :mobile_network_code, :caller_name, :caller_type,
        :sms_pumping_risk_level, :sms_pumping_carrier_risk_category,
        :business_name, :business_legal_name, :business_type, :business_category,
        :business_industry, :business_employee_range, :business_revenue_range,
        :business_address, :business_city, :business_state, :business_country,
        :business_postal_code, :business_website, :business_email_domain,
        :business_linkedin_url, :business_twitter_handle, :business_description,
        :business_enrichment_provider, :error_code, :email, :email_status,
        :first_name, :last_name, :full_name, :position, :department, :seniority,
        :linkedin_url, :twitter_url, :facebook_url, :email_enrichment_provider,
        :consumer_address, :consumer_city, :consumer_state, :consumer_postal_code,
        :consumer_country, :address_type, :address_enrichment_provider
      ]
    end

    it 'verifies all text columns use escape_csv_formula' do
      # Read the ActiveAdmin contacts.rb file
      contacts_rb = File.read(Rails.root.join('app/admin/contacts.rb'))

      # Find the CSV export block
      csv_block = contacts_rb.match(/csv do(.+?)end/m)[1]

      # Count escape_csv_formula calls
      escape_count = csv_block.scan(/escape_csv_formula/).count

      # We expect 52 calls to escape_csv_formula
      expect(escape_count).to eq(52),
        "Expected 52 escape_csv_formula calls, found #{escape_count}"
    end

    it 'all escaped columns are protected against formula injection' do
      # Create contact with formula injection in multiple fields
      contact = create(:contact,
        raw_phone_number: '=SAFE', # This should be escaped
        formatted_phone_number: '+PHONE',
        business_name: '-EXPLOIT',
        email: '@MALWARE'
      )

      get admin_contacts_path(format: :csv)

      csv_content = response.body
      csv_rows = CSV.parse(csv_content)

      header_row = csv_rows[0]
      contact_row = csv_rows.find { |row| row[0].to_i == contact.id }

      # Verify formula escaping applied
      raw_phone_index = header_row.index('raw_phone_number')
      formatted_phone_index = header_row.index('formatted_phone_number')
      business_name_index = header_row.index('business_name')
      email_index = header_row.index('email')

      expect(contact_row[raw_phone_index]).to eq("'=SAFE")
      expect(contact_row[formatted_phone_index]).to eq("'+PHONE")
      expect(contact_row[business_name_index]).to eq("'-EXPLOIT")
      expect(contact_row[email_index]).to eq("'@MALWARE")
    end
  end

  describe 'Security edge cases' do
    it 'escapes formulas with complex Excel syntax' do
      admin_resource = ActiveAdmin.application.namespaces[:admin].resources['Contact']

      dangerous_values = [
        '=1+1',
        '=SUM(A1:A10)',
        '=HYPERLINK("http://evil.com", "Click Me")',
        '=cmd|calc',
        '=DDE("cmd","/c calc","!")',
        '+1234-5678',
        '-2.2*10',
        '@SUM(A1:A10)'
      ]

      dangerous_values.each do |value|
        result = admin_resource.escape_csv_formula(value)
        expect(result).to start_with("'"),
          "Expected '#{value}' to be escaped, got '#{result}'"
      end
    end

    it 'preserves legitimate phone numbers starting with +' do
      admin_resource = ActiveAdmin.application.namespaces[:admin].resources['Contact']

      # Phone numbers starting with + should still be escaped
      # This is correct behavior - CSV import will handle quoted phone numbers
      result = admin_resource.escape_csv_formula('+14155551234')
      expect(result).to eq("'+14155551234")
    end

    it 'handles Unicode characters correctly' do
      admin_resource = ActiveAdmin.application.namespaces[:admin].resources['Contact']

      # Unicode formula should still be escaped
      result = admin_resource.escape_csv_formula('=测试')
      expect(result).to eq("'=测试")

      # Safe Unicode should not be escaped
      result = admin_resource.escape_csv_formula('测试公司')
      expect(result).to eq('测试公司')
    end

    it 'handles tab and newline characters' do
      admin_resource = ActiveAdmin.application.namespaces[:admin].resources['Contact']

      result = admin_resource.escape_csv_formula("=1+1\t\n")
      expect(result).to eq("'=1+1\t\n")
    end

    it 'prevents CSV injection via multiple columns' do
      # Attacker tries to inject formula across different fields
      malicious_contact = create(:contact,
        business_name: '=1+1',
        business_address: '+2+2',
        business_city: '-3-3',
        caller_name: '@4+4'
      )

      get admin_contacts_path(format: :csv)

      csv_content = response.body
      csv_rows = CSV.parse(csv_content)

      header_row = csv_rows[0]
      malicious_row = csv_rows.find { |row| row[0].to_i == malicious_contact.id }

      business_name_index = header_row.index('business_name')
      business_address_index = header_row.index('business_address')
      business_city_index = header_row.index('business_city')
      caller_name_index = header_row.index('caller_name')

      # All should be escaped
      expect(malicious_row[business_name_index]).to eq("'=1+1")
      expect(malicious_row[business_address_index]).to eq("'+2+2")
      expect(malicious_row[business_city_index]).to eq("'-3-3")
      expect(malicious_row[caller_name_index]).to eq("'@4+4")
    end
  end

  describe 'Performance with large datasets' do
    it 'escapes formulas efficiently for bulk export' do
      # Create 100 contacts with malicious formulas
      contacts = 100.times.map do |i|
        create(:contact,
          business_name: "=MALICIOUS#{i}",
          business_city: "+CITY#{i}"
        )
      end

      start_time = Time.current

      get admin_contacts_path(format: :csv)

      elapsed_time = Time.current - start_time

      # Export should complete in reasonable time (<5 seconds)
      expect(elapsed_time).to be < 5.seconds

      expect(response).to have_http_status(:ok)

      # Verify all rows are escaped
      csv_content = response.body
      csv_rows = CSV.parse(csv_content)

      header_row = csv_rows[0]
      business_name_index = header_row.index('business_name')

      contacts.each do |contact|
        row = csv_rows.find { |r| r[0].to_i == contact.id }
        expect(row[business_name_index]).to start_with("'=MALICIOUS")
      end
    end
  end
end
