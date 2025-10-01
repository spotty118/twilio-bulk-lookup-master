# ========================================
# Twilio Bulk Lookup - Database Seeds
# ========================================
# This file creates sample data for development and testing

puts "\n" + "="*60
puts "🌱 Seeding Database for #{Rails.env} environment"
puts "="*60
puts ""

# ========================================
# 1. Create Admin User
# ========================================
puts "👤 Creating Admin User..."

admin = AdminUser.find_or_create_by!(email: 'admin@example.com') do |user|
  user.password = 'password'
  user.password_confirmation = 'password'
end

puts "   ✅ Admin created: #{admin.email}"
puts "   📧 Email: admin@example.com"
puts "   🔑 Password: password"
puts ""

# ========================================
# 2. Create Sample Twilio Credentials (Development Only)
# ========================================
if Rails.env.development? || Rails.env.test?
  puts "🔐 Creating Sample Twilio Credentials..."
  
  # Only create if not using environment variables
  unless ENV['TWILIO_ACCOUNT_SID'].present?
    twilio_cred = TwilioCredential.first_or_create!(
      account_sid: 'AC' + SecureRandom.hex(16),  # Fake SID for demo
      auth_token: SecureRandom.hex(16)           # Fake token for demo
    )
    
    puts "   ⚠️  Sample credentials created (NOT REAL)"
    puts "   💡 To use real credentials, set environment variables:"
    puts "      export TWILIO_ACCOUNT_SID='your_real_sid'"
    puts "      export TWILIO_AUTH_TOKEN='your_real_token'"
    puts ""
  else
    puts "   ✅ Using credentials from environment variables"
    puts ""
  end
end

# ========================================
# 3. Create Sample Contacts (Development Only)
# ========================================
if Rails.env.development?
  puts "📞 Creating Sample Contacts..."
  
  sample_contacts = [
    # Completed contacts with various carriers
    { raw: '+14155551001', formatted: '+14155551001', carrier: 'Verizon', device: 'mobile', status: 'completed' },
    { raw: '+14155551002', formatted: '+14155551002', carrier: 'AT&T', device: 'mobile', status: 'completed' },
    { raw: '+14155551003', formatted: '+14155551003', carrier: 'T-Mobile', device: 'mobile', status: 'completed' },
    { raw: '+14155551004', formatted: '+14155551004', carrier: 'Sprint', device: 'mobile', status: 'completed' },
    { raw: '+14155551005', formatted: '+14155551005', carrier: 'Verizon', device: 'landline', status: 'completed' },
    { raw: '+14155551006', formatted: '+14155551006', carrier: 'AT&T', device: 'landline', status: 'completed' },
    { raw: '+14155551007', formatted: '+14155551007', carrier: 'Vonage', device: 'voip', status: 'completed' },
    { raw: '+14155551008', formatted: '+14155551008', carrier: 'Google Voice', device: 'voip', status: 'completed' },
    { raw: '+14155551009', formatted: '+14155551009', carrier: 'T-Mobile', device: 'mobile', status: 'completed' },
    { raw: '+14155551010', formatted: '+14155551010', carrier: 'Verizon', device: 'mobile', status: 'completed' },
    
    # Pending contacts
    { raw: '+14155552001', status: 'pending' },
    { raw: '+14155552002', status: 'pending' },
    { raw: '+14155552003', status: 'pending' },
    { raw: '+14155552004', status: 'pending' },
    { raw: '+14155552005', status: 'pending' },
    
    # Processing contacts
    { raw: '+14155553001', status: 'processing' },
    { raw: '+14155553002', status: 'processing' },
    
    # Failed contacts with various errors
    { raw: '+1234567890', status: 'failed', error: 'Invalid phone number format' },
    { raw: '555-1234', status: 'failed', error: 'Invalid phone number format' },
    { raw: '+14155559999', status: 'failed', error: 'Number not found' },
  ]
  
  created_count = 0
  sample_contacts.each do |contact_data|
    contact = Contact.find_or_create_by(raw_phone_number: contact_data[:raw]) do |c|
      c.formatted_phone_number = contact_data[:formatted]
      c.carrier_name = contact_data[:carrier]
      c.device_type = contact_data[:device]
      c.status = contact_data[:status]
      c.error_code = contact_data[:error]
      
      # Set timestamps for completed contacts
      if contact_data[:status] == 'completed'
        c.lookup_performed_at = rand(1..48).hours.ago
      end
      
      # Add mobile codes for mobile devices
      if contact_data[:device] == 'mobile'
        c.mobile_country_code = '310'
        c.mobile_network_code = rand(100..999).to_s
      end
    end
    
    created_count += 1 if contact.persisted?
  end
  
  puts "   ✅ Created #{created_count} sample contacts"
  puts ""
  
  # Show statistics
  puts "📊 Contact Statistics:"
  puts "   Total: #{Contact.count}"
  puts "   Pending: #{Contact.pending.count}"
  puts "   Processing: #{Contact.processing.count}"
  puts "   Completed: #{Contact.completed.count}"
  puts "   Failed: #{Contact.failed.count}"
  puts ""
end

# ========================================
# 4. Display Summary
# ========================================
puts "="*60
puts "✅ Seeding Complete!"
puts "="*60
puts ""
puts "🚀 Next Steps:"
puts "   1. Start Rails server: rails server"
puts "   2. Start Sidekiq: bundle exec sidekiq -C config/sidekiq.yml"
puts "   3. Visit admin panel: http://localhost:3000/admin"
puts "   4. Login with:"
puts "      Email: admin@example.com"
puts "      Password: password"
puts ""
puts "💡 Tips:"
puts "   - Run 'rake contacts:stats' to see detailed statistics"
puts "   - Run 'rake twilio:test_credentials' to verify Twilio setup"
puts "   - Check the dashboard for analytics and processing controls"
puts ""
puts "="*60
puts ""