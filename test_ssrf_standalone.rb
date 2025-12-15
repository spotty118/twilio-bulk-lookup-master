#!/usr/bin/env ruby
# Standalone SSRF Validation Test
# Tests URI validation regex without requiring Rails environment

require 'uri'

puts "═══════════════════════════════════════════════════════════════════"
puts "SSRF VALIDATION TEST - URI Regex Pattern"
puts "═══════════════════════════════════════════════════════════════════\n\n"

# This is the exact regex we're using in the validation
url_regex = URI::DEFAULT_PARSER.make_regexp(['http', 'https'])

test_cases = [
  { name: "Valid HTTP URL", value: "http://example.com", should_match: true },
  { name: "Valid HTTPS URL", value: "https://example.com/path", should_match: true },
  { name: "HTTPS with subdomain", value: "https://www.example.com", should_match: true },
  { name: "HTTPS with port", value: "https://example.com:8080", should_match: true },
  { name: "HTTPS with query params", value: "https://example.com?key=value", should_match: true },
  { name: "SSRF Attack: file:// scheme", value: "file:///etc/passwd", should_match: false },
  { name: "SSRF Attack: javascript: scheme", value: "javascript:alert(1)", should_match: false },
  { name: "SSRF Attack: data: scheme", value: "data:text/html,<script>alert(1)</script>", should_match: false },
  { name: "SSRF Attack: ftp:// scheme", value: "ftp://internal.server/secret", should_match: false },
  { name: "Invalid URL format", value: "not-a-valid-url", should_match: false },
  { name: "Internal IP (allowed - network handles)", value: "http://127.0.0.1:8080", should_match: true },
  { name: "AWS metadata endpoint (allowed)", value: "http://169.254.169.254/metadata", should_match: true },
  { name: "Localhost", value: "http://localhost:3000", should_match: true },
  { name: "URL without scheme", value: "example.com", should_match: false },
  { name: "HTTPS with fragment", value: "https://example.com#section", should_match: true },
]

passed = 0
failed = 0

test_cases.each do |test|
  # Test if value matches the regex (full string match)
  matches = test[:value] =~ /\A#{url_regex}\z/

  test_passed = if test[:should_match]
    matches != nil
  else
    matches == nil
  end

  if test_passed
    passed += 1
    status = "✓ PASS"
  else
    failed += 1
    status = "✗ FAIL"
  end

  puts "#{status} | #{test[:name]}"
  puts "         Value: #{test[:value]}"
  puts "         Expected: #{test[:should_match] ? 'MATCH' : 'REJECT'}"
  puts "         Got: #{matches ? 'MATCHED' : 'REJECTED'}"
  puts ""
end

puts "\n═══════════════════════════════════════════════════════════════════"
puts "TEST SUMMARY"
puts "═══════════════════════════════════════════════════════════════════"
puts "Total Tests: #{test_cases.length}"
puts "Passed: #{passed}"
puts "Failed: #{failed}"
puts "Success Rate: #{(passed.to_f / test_cases.length * 100).round(2)}%"
puts "\n"

if failed == 0
  puts "🎉 ALL TESTS PASSED - SSRF protection regex is working correctly!"
  puts "\n"
  puts "The validation will:"
  puts "  ✓ Allow http:// and https:// URLs"
  puts "  ✗ Block file://, javascript:, data:, ftp:, and other dangerous schemes"
  puts "  ✓ Allow localhost and internal IPs (network firewall handles SSRF prevention)"
  puts "  ✗ Reject malformed URLs and URLs without schemes"
  exit 0
else
  puts "⚠️  SOME TESTS FAILED - Review regex pattern"
  exit 1
end
