# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Contact URL Validation (SSRF Prevention)', type: :model do
  # COGNITIVE HYPERCLUSTER TEST SUITE
  # Test Fix: URL validation prevents SSRF (Server-Side Request Forgery) attacks
  # Coverage: business_website field validation
  # Edge Cases: javascript:, file://, data:, ftp://, gopher://, etc.
  # Security: Only allow http:// and https:// schemes

  describe 'business_website URL validation' do
    it 'accepts valid http URL' do
      contact = build(:contact, business_website: 'http://example.com')
      expect(contact).to be_valid
      expect(contact.errors[:business_website]).to be_empty
    end

    it 'accepts valid https URL' do
      contact = build(:contact, business_website: 'https://example.com')
      expect(contact).to be_valid
      expect(contact.errors[:business_website]).to be_empty
    end

    it 'accepts http URL with path' do
      contact = build(:contact, business_website: 'http://example.com/path/to/page')
      expect(contact).to be_valid
    end

    it 'accepts https URL with query parameters' do
      contact = build(:contact, business_website: 'https://example.com/page?foo=bar&baz=qux')
      expect(contact).to be_valid
    end

    it 'accepts URL with subdomain' do
      contact = build(:contact, business_website: 'https://www.example.com')
      expect(contact).to be_valid
    end

    it 'accepts URL with port' do
      contact = build(:contact, business_website: 'http://example.com:8080')
      expect(contact).to be_valid
    end

    it 'accepts URL with authentication' do
      contact = build(:contact, business_website: 'https://user:pass@example.com')
      expect(contact).to be_valid
    end

    it 'accepts URL with fragment' do
      contact = build(:contact, business_website: 'https://example.com#section')
      expect(contact).to be_valid
    end

    it 'accepts complex valid URL' do
      contact = build(:contact,
        business_website: 'https://subdomain.example.com:8443/path/to/resource?query=value&foo=bar#fragment'
      )
      expect(contact).to be_valid
    end

    it 'allows blank/nil business_website (not required)' do
      contact = build(:contact, business_website: nil)
      expect(contact).to be_valid

      contact = build(:contact, business_website: '')
      expect(contact).to be_valid
    end
  end

  describe 'SSRF attack prevention' do
    it 'rejects javascript: URLs (XSS vector)' do
      contact = build(:contact, business_website: 'javascript:alert(1)')
      expect(contact).not_to be_valid
      expect(contact.errors[:business_website]).to include('must be a valid HTTP or HTTPS URL')
    end

    it 'rejects file:// URLs (local file access)' do
      contact = build(:contact, business_website: 'file:///etc/passwd')
      expect(contact).not_to be_valid
      expect(contact.errors[:business_website]).to include('must be a valid HTTP or HTTPS URL')
    end

    it 'rejects file:// with Windows paths' do
      contact = build(:contact, business_website: 'file:///C:/Windows/System32/config/sam')
      expect(contact).not_to be_valid
      expect(contact.errors[:business_website]).to include('must be a valid HTTP or HTTPS URL')
    end

    it 'rejects data: URLs (data exfiltration)' do
      contact = build(:contact, business_website: 'data:text/html,<script>alert(1)</script>')
      expect(contact).not_to be_valid
      expect(contact.errors[:business_website]).to include('must be a valid HTTP or HTTPS URL')
    end

    it 'rejects ftp:// URLs (non-web protocol)' do
      contact = build(:contact, business_website: 'ftp://ftp.example.com')
      expect(contact).not_to be_valid
      expect(contact.errors[:business_website]).to include('must be a valid HTTP or HTTPS URL')
    end

    it 'rejects gopher:// URLs (deprecated protocol)' do
      contact = build(:contact, business_website: 'gopher://gopher.example.com')
      expect(contact).not_to be_valid
      expect(contact.errors[:business_website]).to include('must be a valid HTTP or HTTPS URL')
    end

    it 'rejects tel: URLs (phone number protocol)' do
      contact = build(:contact, business_website: 'tel:+14155551234')
      expect(contact).not_to be_valid
      expect(contact.errors[:business_website]).to include('must be a valid HTTP or HTTPS URL')
    end

    it 'rejects mailto: URLs (email protocol)' do
      contact = build(:contact, business_website: 'mailto:user@example.com')
      expect(contact).not_to be_valid
      expect(contact.errors[:business_website]).to include('must be a valid HTTP or HTTPS URL')
    end

    it 'rejects ssh:// URLs (secure shell protocol)' do
      contact = build(:contact, business_website: 'ssh://user@server.com')
      expect(contact).not_to be_valid
      expect(contact.errors[:business_website]).to include('must be a valid HTTP or HTTPS URL')
    end

    it 'rejects smb:// URLs (Windows file sharing)' do
      contact = build(:contact, business_website: 'smb://server/share')
      expect(contact).not_to be_valid
      expect(contact.errors[:business_website]).to include('must be a valid HTTP or HTTPS URL')
    end

    it 'rejects ldap:// URLs (directory protocol)' do
      contact = build(:contact, business_website: 'ldap://ldap.example.com')
      expect(contact).not_to be_valid
      expect(contact.errors[:business_website]).to include('must be a valid HTTP or HTTPS URL')
    end

    it 'rejects dict:// URLs (dictionary protocol)' do
      contact = build(:contact, business_website: 'dict://dict.example.com')
      expect(contact).not_to be_valid
      expect(contact.errors[:business_website]).to include('must be a valid HTTP or HTTPS URL')
    end

    it 'rejects about:blank URLs' do
      contact = build(:contact, business_website: 'about:blank')
      expect(contact).not_to be_valid
      expect(contact.errors[:business_website]).to include('must be a valid HTTP or HTTPS URL')
    end

    it 'rejects chrome:// URLs (browser protocol)' do
      contact = build(:contact, business_website: 'chrome://settings')
      expect(contact).not_to be_valid
      expect(contact.errors[:business_website]).to include('must be a valid HTTP or HTTPS URL')
    end

    it 'rejects view-source: URLs' do
      contact = build(:contact, business_website: 'view-source:http://example.com')
      expect(contact).not_to be_valid
      expect(contact.errors[:business_website]).to include('must be a valid HTTP or HTTPS URL')
    end
  end

  describe 'SSRF edge cases - localhost and internal IPs' do
    it 'accepts localhost URLs (application should handle access control separately)' do
      # URL validation only checks scheme, not hostname
      # Application-level access control should prevent SSRF to internal IPs
      contact = build(:contact, business_website: 'http://localhost:3000')
      expect(contact).to be_valid
    end

    it 'accepts 127.0.0.1 URLs (validation only checks scheme)' do
      contact = build(:contact, business_website: 'http://127.0.0.1')
      expect(contact).to be_valid
    end

    it 'accepts private IP ranges (validation only checks scheme)' do
      contact = build(:contact, business_website: 'http://192.168.1.1')
      expect(contact).to be_valid

      contact = build(:contact, business_website: 'http://10.0.0.1')
      expect(contact).to be_valid

      contact = build(:contact, business_website: 'http://172.16.0.1')
      expect(contact).to be_valid
    end

    # Note: The validation ensures only http/https schemes are allowed.
    # Additional SSRF protection (blocking internal IPs, localhost, etc.)
    # should be implemented at the HTTP client level when making requests.
  end

  describe 'URL format edge cases' do
    it 'rejects invalid URL formats' do
      contact = build(:contact, business_website: 'not a valid url')
      expect(contact).not_to be_valid
      expect(contact.errors[:business_website]).to include('must be a valid HTTP or HTTPS URL')
    end

    it 'rejects URLs with missing scheme' do
      contact = build(:contact, business_website: 'example.com')
      expect(contact).not_to be_valid
      expect(contact.errors[:business_website]).to include('must be a valid HTTP or HTTPS URL')
    end

    it 'rejects URLs with only scheme' do
      contact = build(:contact, business_website: 'http://')
      expect(contact).not_to be_valid
      expect(contact.errors[:business_website]).to include('must be a valid HTTP or HTTPS URL')
    end

    it 'rejects malformed URLs' do
      contact = build(:contact, business_website: 'http://[invalid')
      expect(contact).not_to be_valid
    end

    it 'accepts IPv6 URLs' do
      contact = build(:contact, business_website: 'http://[2001:db8::1]')
      expect(contact).to be_valid
    end

    it 'accepts URLs with international domain names (IDN)' do
      contact = build(:contact, business_website: 'http://例え.jp')
      expect(contact).to be_valid
    end

    it 'handles URLs with percent-encoded characters' do
      contact = build(:contact, business_website: 'http://example.com/path%20with%20spaces')
      expect(contact).to be_valid
    end

    it 'handles URLs with unicode characters' do
      contact = build(:contact, business_website: 'http://例え.jp/パス')
      expect(contact).to be_valid
    end
  end

  describe 'Conditional validation (only on change)' do
    it 'only validates business_website when changed' do
      # Create contact with valid URL
      contact = create(:contact, business_website: 'http://example.com')

      # Update other field (business_website unchanged)
      expect {
        contact.update!(business_name: 'New Name')
      }.not_to raise_error

      expect(contact.reload.business_name).to eq('New Name')
    end

    it 'validates when business_website is changed' do
      contact = create(:contact, business_website: 'http://example.com')

      # Try to update to invalid URL
      expect {
        contact.update!(business_website: 'javascript:alert(1)')
      }.to raise_error(ActiveRecord::RecordInvalid)

      expect(contact.reload.business_website).to eq('http://example.com')
    end

    it 'allows creating contact with existing invalid data (legacy support)' do
      # If database already has invalid URLs from before validation was added,
      # we can still load and update other fields
      contact = create(:contact, business_website: 'http://example.com')

      # Manually update to invalid URL in DB (bypassing validation)
      contact.update_column(:business_website, 'javascript:alert(1)')

      # Reload and update other field (should not re-validate business_website)
      contact.reload
      contact.business_name = 'Updated Name'

      # Should save without re-validating business_website
      # (conditional validation: if: changed?)
      expect(contact.save).to be true
    end
  end

  describe 'Security best practices' do
    it 'uses URI::DEFAULT_PARSER.make_regexp for strict validation' do
      # Verify validation uses URI parser (not custom regex)
      validation = Contact.validators_on(:business_website).find { |v| v.is_a?(ActiveModel::Validations::FormatValidator) }

      expect(validation).to be_present
      expect(validation.options[:with]).to eq(URI::DEFAULT_PARSER.make_regexp(['http', 'https']))
    end

    it 'only allows http and https schemes (whitelist approach)' do
      # Whitelist approach is more secure than blacklist
      # Verify only http and https are in the allowed schemes
      allowed_schemes = URI::DEFAULT_PARSER.make_regexp(['http', 'https'])

      # Test that other schemes don't match
      ['ftp', 'file', 'javascript', 'data', 'gopher'].each do |scheme|
        url = "#{scheme}://example.com"
        expect(url).not_to match(allowed_schemes),
          "Scheme '#{scheme}' should not be allowed"
      end

      # Test that http and https DO match
      ['http', 'https'].each do |scheme|
        url = "#{scheme}://example.com"
        expect(url).to match(allowed_schemes),
          "Scheme '#{scheme}' should be allowed"
      end
    end

    it 'provides clear error message for invalid URLs' do
      contact = build(:contact, business_website: 'javascript:alert(1)')
      contact.valid?

      error_message = contact.errors[:business_website].first
      expect(error_message).to eq('must be a valid HTTP or HTTPS URL')
      expect(error_message).to include('HTTP or HTTPS')
    end
  end

  describe 'Real-world URL examples' do
    let(:valid_urls) do
      [
        'http://example.com',
        'https://example.com',
        'https://www.example.com',
        'http://example.com:8080',
        'https://subdomain.example.com/path/to/page',
        'http://example.com/path?query=value',
        'https://example.com#fragment',
        'http://example.com/path?foo=bar&baz=qux#section',
        'https://example.co.uk',
        'http://example.com/~user',
        'https://example.com:443/secure',
        'http://192.168.1.1', # IP address (valid scheme, app should block if needed)
        'http://[2001:db8::1]', # IPv6
        'https://user:pass@example.com', # Authentication
        'http://example.com:8080/path?query=value#fragment' # Full URL
      ]
    end

    let(:invalid_urls) do
      [
        'javascript:alert(1)',
        'file:///etc/passwd',
        'data:text/html,<script>alert(1)</script>',
        'ftp://ftp.example.com',
        'gopher://gopher.example.com',
        'tel:+14155551234',
        'mailto:user@example.com',
        'ssh://user@server.com',
        'smb://server/share',
        'ldap://ldap.example.com',
        'dict://dict.example.com',
        'about:blank',
        'chrome://settings',
        'view-source:http://example.com',
        'example.com', # Missing scheme
        'http://', # Missing host
        'not a url' # Invalid format
      ]
    end

    it 'accepts all valid real-world URLs' do
      valid_urls.each do |url|
        contact = build(:contact, business_website: url)
        expect(contact).to be_valid,
          "Expected '#{url}' to be valid, but got errors: #{contact.errors[:business_website].join(', ')}"
      end
    end

    it 'rejects all invalid/dangerous URLs' do
      invalid_urls.each do |url|
        contact = build(:contact, business_website: url)
        expect(contact).not_to be_valid,
          "Expected '#{url}' to be invalid, but it was accepted"
        expect(contact.errors[:business_website]).to include('must be a valid HTTP or HTTPS URL')
      end
    end
  end
end
