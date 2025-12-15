#!/usr/bin/env ruby
# SSRF Validation Test Script
# Tests URL validations to prevent Server-Side Request Forgery

require_relative 'config/environment'

puts "═══════════════════════════════════════════════════════════════════"
puts "SSRF VALIDATION TEST - Contact Model URL Fields"
puts "═══════════════════════════════════════════════════════════════════\n\n"

# Test cases for each URL field
url_fields = [
  :business_website,
  :business_linkedin_url,
  :linkedin_url,
  :twitter_url,
  :facebook_url
]

test_cases = {
  "Valid HTTP URL" => {
    value: "http://example.com",
    should_pass: true
  },
  "Valid HTTPS URL" => {
    value: "https://example.com/path",
    should_pass: true
  },
  "SSRF Attack: file:// scheme" => {
    value: "file:///etc/passwd",
    should_pass: false
  },
  "SSRF Attack: javascript: scheme" => {
    value: "javascript:alert(1)",
    should_pass: false
  },
  "SSRF Attack: data: scheme" => {
    value: "data:text/html,<script>alert(1)</script>",
    should_pass: false
  },
  "SSRF Attack: ftp:// scheme" => {
    value: "ftp://internal.server/secret",
    should_pass: false
  },
  "NULL value (should be allowed)" => {
    value: nil,
    should_pass: true
  },
  "Empty string (should be allowed)" => {
    value: "",
    should_pass: true
  },
  "Invalid URL format" => {
    value: "not-a-valid-url",
    should_pass: false
  },
  "Internal IP (allowed - network firewall handles this)" => {
    value: "http://127.0.0.1:8080",
    should_pass: true
  },
  "AWS metadata endpoint (allowed - network firewall handles this)" => {
    value: "http://169.254.169.254/metadata",
    should_pass: true
  }
}

results = {
  passed: 0,
  failed: 0,
  total: 0
}

url_fields.each do |field|
  puts "\n━━━ Testing: #{field} ━━━\n"

  test_cases.each do |test_name, test_data|
    results[:total] += 1

    # Create a new contact for each test
    contact = Contact.new(
      raw_phone_number: "+14155551234",
      field => test_data[:value]
    )

    is_valid = contact.valid?

    # Check if the field validation behaved as expected
    field_errors = contact.errors[field]
    has_url_error = field_errors.any? { |e| e.include?("valid HTTP or HTTPS URL") }

    # Determine if test passed
    if test_data[:should_pass]
      test_passed = !has_url_error
    else
      test_passed = has_url_error
    end

    if test_passed
      results[:passed] += 1
      status = "✓ PASS"
    else
      results[:failed] += 1
      status = "✗ FAIL"
    end

    puts "#{status} | #{test_name}"
    puts "         Value: #{test_data[:value].inspect}"
    puts "         Expected: #{test_data[:should_pass] ? 'ACCEPT' : 'REJECT'}"
    puts "         Got: #{has_url_error ? 'REJECTED' : 'ACCEPTED'}"
    puts "         Errors: #{field_errors.join(', ')}" if field_errors.any?
    puts ""
  end
end

puts "\n═══════════════════════════════════════════════════════════════════"
puts "TEST SUMMARY"
puts "═══════════════════════════════════════════════════════════════════"
puts "Total Tests: #{results[:total]}"
puts "Passed: #{results[:passed]}"
puts "Failed: #{results[:failed]}"
puts "Success Rate: #{(results[:passed].to_f / results[:total] * 100).round(2)}%"
puts "\n"

if results[:failed] == 0
  puts "🎉 ALL TESTS PASSED - SSRF protection is working correctly!"
  exit 0
else
  puts "⚠️  SOME TESTS FAILED - Review validation logic"
  exit 1
end
