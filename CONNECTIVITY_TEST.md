# Frontend-Backend Connectivity Verification

This guide helps verify that all components are properly connected.

## Quick Health Check

Run this from Rails console to verify everything is connected:

```ruby
# Rails console
rails console

# 1. Test database connectivity
Contact.count
AdminUser.count

# 2. Test new migrations applied
Contact.column_names.include?('verizon_5g_probability')
# => Should return true

AdminUserColumnPreference.table_exists?
# => Should return true

# 3. Test model associations
admin = AdminUser.first
admin.column_preferences_for('Contact')
# => Should return AdminUserColumnPreference instance

# 4. Test default column configuration
pref = AdminUserColumnPreference.new
pref.column_config.count
# => Should return 15 (number of columns)

# 5. Test Contact probability methods
contact = Contact.first
contact.respond_to?(:verizon_5g_probability_badge)
# => Should return true

# 6. Test services can be instantiated
require 'open_cell_id_service'
OpenCellIdService.new(40.7128, -74.0060)
# => Should create service instance

# 7. Test VerizonProbabilityService
contact = Contact.where.not(latitude: nil).first
VerizonProbabilityService.new(contact)
# => Should create service instance
```

## Frontend-Backend Route Connectivity

### 1. Verify ActiveAdmin Routes

```bash
cd /workspace/cmgynngnl0022q2i2a3z0ps7r/twilio-bulk-lookup-master
rails routes | grep column_settings
```

Expected output:
```
admin_contacts_column_settings GET    /admin/contacts/column_settings(.:format)        admin/contacts#column_settings
admin_contacts_update_column_settings POST   /admin/contacts/update_column_settings(.:format) admin/contacts#update_column_settings
admin_contacts_reset_column_settings POST   /admin/contacts/reset_column_settings(.:format)  admin/contacts#reset_column_settings
```

### 2. Verify View Can Be Rendered

```ruby
# Rails console
ApplicationController.renderer.render(
  partial: 'admin/contacts/column_settings',
  locals: {
    preference: AdminUserColumnPreference.new
  }
)
# => Should return HTML string without errors
```

### 3. Test JavaScript Loading

1. Start Rails server: `rails server`
2. Navigate to: `http://localhost:3000/admin/contacts`
3. Open browser developer console
4. Check for JavaScript errors
5. Click "Customize Columns" button
6. Verify SortableJS loaded: `typeof Sortable` should return `"function"`

### 4. Test Column Settings Form Submission

From browser console on column settings page:

```javascript
// Check form exists
document.querySelector('form[action*="update_column_settings"]')
// => Should return form element

// Check CSRF token present
document.querySelector('input[name="authenticity_token"]')?.value
// => Should return token string

// Check column items render
document.querySelectorAll('.column-item').length
// => Should return 15 (number of columns)
```

### 5. Test Backend Processing

```ruby
# Rails console
user = AdminUser.first

# Simulate form submission
columns_params = [
  { field: 'id', visible: true, label: 'ID', position: 1 },
  { field: 'raw_phone_number', visible: true, label: 'Phone', position: 2 },
  { field: 'status', visible: false, label: 'Status', position: 3 }
]

pref = user.column_preferences_for('Contact')
pref.update_column_config(columns_params)
# => Should return true

# Verify saved
pref.reload
pref.column_config.find { |c| c[:field] == 'status' }[:visible]
# => Should return false
```

## Component Integration Tests

### 1. Full Column Customization Flow

```ruby
# Create test admin user
user = AdminUser.create!(
  email: 'test@example.com',
  password: 'password123',
  password_confirmation: 'password123'
)

# Get default preferences
pref = user.column_preferences_for('Contact')
pref.column_config.count # => 15

# Customize columns
pref.update_column_config([
  { field: 'id', visible: true, label: 'Contact ID', position: 1 },
  { field: 'raw_phone_number', visible: true, label: 'Phone #', position: 2 }
])

# Verify persistence
pref.reload
pref.column_config.first[:label] # => "Contact ID"

# Reset to defaults
pref.reset_to_defaults!
pref.column_config.first[:label] # => "ID"
```

### 2. Verizon Probability Calculation Flow

```ruby
# Create test contact with address
contact = Contact.create!(
  raw_phone_number: '+14155551234',
  consumer_address: '1 Verizon Way',
  consumer_city: 'Basking Ridge',
  consumer_state: 'NJ',
  consumer_postal_code: '07920',
  latitude: 40.706,
  longitude: -74.530,
  verizon_coverage_checked: true
)

# Calculate probability
service = VerizonProbabilityService.new(contact)
result = service.calculate_probabilities

# Check result structure
result.keys # => [:five_g, :lte, :tower_data]
result[:five_g].between?(0, 100) # => true
result[:lte].between?(0, 100) # => true

# Update contact
contact.verizon_5g_probability = result[:five_g]
contact.verizon_lte_probability = result[:lte]
contact.save!

# Test badge methods
badge = contact.verizon_5g_probability_badge
badge.keys # => [:percentage, :status, :label]
badge[:status] # => 'high', 'medium', or 'low'
```

### 3. Background Job Flow

```ruby
# Queue probability calculation
contact = Contact.where.not(latitude: nil).first
VerizonProbabilityCalculationJob.perform_later(contact.id)

# Check job queued (if using Sidekiq)
Sidekiq::Queue.new.size # => Should be > 0

# Or run synchronously
VerizonProbabilityCalculationJob.perform_now(contact.id)

# Verify contact updated
contact.reload
contact.verizon_5g_probability # => Should have value 0-100
```

## API Endpoint Tests

### Test Verizon Public API

```bash
# From command line
curl -X POST https://www.verizon.com/sales/nextgen/apigateway/v1/serviceability/home \
  -H "Content-Type: application/json" \
  -H "User-Agent: Mozilla/5.0" \
  -d '{
    "address": {
      "addressLine1": "1 Verizon Way",
      "city": "Basking Ridge",
      "state": "NJ",
      "zipCode": "07920"
    }
  }'
```

From Rails console:
```ruby
contact = Contact.where.not(consumer_address: nil).first
service = VerizonCoverageService.new(contact)
result = service.send(:try_verizon_public_api)
result # => Should return hash with availability data
```

### Test OpenCellID API

```bash
# Requires API key
curl "https://opencellid.org/cell/getInArea?key=YOUR_KEY&lat=40.706&lon=-74.530&radius=10000&format=json&radio=all"
```

From Rails console:
```ruby
# Set API key first
ENV['OPENCELLID_API_KEY'] = 'your_key_here'

service = OpenCellIdService.new(40.706, -74.530)
towers = service.fetch_nearby_towers('all', 10)
towers.count # => Should return array of towers
```

## Common Issues & Solutions

### Issue: SortableJS not loaded

**Symptoms:** Drag and drop doesn't work

**Solution:**
1. Check script tag in column settings view
2. Verify CDN accessible: Visit https://cdn.jsdelivr.net/npm/sortablejs@1.15.0/Sortable.min.js
3. Check browser console for errors
4. Try clearing browser cache

### Issue: Column preferences not saving

**Symptoms:** Changes revert after page reload

**Solution:**
```ruby
# Check model validations
pref = AdminUserColumnPreference.new
pref.preferences = { 'columns' => [] }
pref.valid? # => Should return true

# Check database
ActiveRecord::Base.connection.execute("SELECT * FROM admin_user_column_preferences LIMIT 5")
# => Should return results if table exists
```

### Issue: Probability always nil

**Symptoms:** verizon_5g_probability stays null

**Checklist:**
1. Contact has latitude/longitude?
   ```ruby
   contact.latitude.present? && contact.longitude.present?
   ```

2. OpenCellID API key set?
   ```ruby
   ENV['OPENCELLID_API_KEY'].present?
   ```

3. Check logs:
   ```bash
   tail -f log/development.log | grep VerizonProbability
   ```

4. Run calculation manually:
   ```ruby
   service = VerizonProbabilityService.new(contact)
   service.calculate_probabilities
   # Check for errors
   ```

### Issue: Routes not found

**Symptoms:** 404 when accessing column settings

**Solution:**
```bash
# Restart Rails server
rails server

# Verify routes loaded
rails routes | grep column

# Check ActiveAdmin loaded contacts resource
rails console
ActiveAdmin.application.namespaces[:admin].resources.map(&:resource_class)
# => Should include Contact
```

## Performance Checks

### Database Query Performance

```ruby
# Test column config query performance
Benchmark.measure do
  1000.times do
    user = AdminUser.first
    user.column_preferences_for('Contact').column_config
  end
end
# => Should complete in < 1 second

# Test contact index query
Benchmark.measure do
  Contact.limit(100).includes(:nothing).to_a
end
# => Should complete in < 500ms
```

### API Response Times

```ruby
require 'benchmark'

contact = Contact.where.not(consumer_address: nil).first

# Test Verizon API
time = Benchmark.measure do
  service = VerizonCoverageService.new(contact)
  service.send(:try_verizon_public_api)
end
puts "Verizon API: #{time.real}s" # Should be < 2s

# Test OpenCellID API
time = Benchmark.measure do
  service = OpenCellIdService.new(40.706, -74.530)
  service.fetch_nearby_towers('all', 10)
end
puts "OpenCellID API: #{time.real}s" # Should be < 3s
```

## Security Checks

### Verify Authorization

```ruby
# Only admin users should access column settings
# Test in browser: logout and try accessing /admin/contacts/column_settings
# => Should redirect to login

# Test programmatically
user = AdminUser.first
user.valid_password?('wrong_password') # => false
```

### CSRF Protection

```ruby
# Verify CSRF token required for POST requests
# Try submitting form without token (should fail)
```

## Success Criteria

All checks should pass:

- [ ] Database migrations applied
- [ ] Models load without errors
- [ ] Routes defined and accessible
- [ ] Views render without errors
- [ ] JavaScript loads (SortableJS available)
- [ ] Form submission works
- [ ] Column preferences persist
- [ ] Probability calculation completes
- [ ] Background jobs process
- [ ] API endpoints respond (with valid credentials)
- [ ] No errors in Rails logs
- [ ] No JavaScript console errors

## Next Steps After Verification

1. Run full test suite: `rails test`
2. Check code coverage
3. Review Rails logs for warnings
4. Test with real production data
5. Monitor API usage and performance
6. Set up error tracking (Sentry, Rollbar, etc.)
