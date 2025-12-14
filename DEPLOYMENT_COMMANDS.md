# Deployment Commands

## Prerequisites Check

```bash
# Verify bundler version matches Gemfile.lock
bundle -v  # Should show 2.7.2 or higher

# Install dependencies if needed
bundle install
```

## 1. Run Database Migration (15 minutes)

```bash
# Development environment
RAILS_ENV=development rails db:migrate

# Production environment (after testing in dev/staging)
RAILS_ENV=production rails db:migrate

# Verify the singleton constraint was added
rails dbconsole
\d twilio_credentials
# Should show: index_twilio_credentials_singleton (unique, partial)
```

**Rollback if issues occur:**
```bash
rails db:rollback
```

## 2. Execute Test Suite (30 minutes)

```bash
# Setup test database (first time only)
RAILS_ENV=test rails db:setup

# Run all specs
bundle exec rspec

# Run specific test files
bundle exec rspec spec/models/twilio_credential_spec.rb
bundle exec rspec spec/admin/ai_assistant_sql_injection_spec.rb

# Expected: 14 passing tests (0 failures)
```

## 3. Enable HttpClient Autoload

Already updated in: `config/application.rb`

Verify in Rails console:
```bash
rails console
> HttpClient
=> HttpClient  # Should load successfully
> HttpClient::TimeoutError
=> HttpClient::TimeoutError
```

## 4. Syntax Validation (Pre-deployment)

```bash
# Check Ruby syntax
ruby -c lib/http_client.rb
ruby -c app/services/business_enrichment_service.rb
ruby -c app/models/twilio_credential.rb

# Run Rubocop (if configured)
bundle exec rubocop --auto-correct

# Security audit with Brakeman
bundle exec brakeman --quiet
```

## 5. Monitor After Deployment

```bash
# Watch logs for circuit breaker activity
tail -f log/production.log | grep -i circuit

# Watch for SQL errors
tail -f log/production.log | grep -i "SQL\|error"

# Check ActiveAdmin for circuit breaker dashboard
# Navigate to: /admin/circuit_breakers (after Phase 5 implementation)
```

## Troubleshooting

### Migration fails with "column already exists"
```bash
# Check current schema
rails dbconsole
\d twilio_credentials

# If is_singleton column exists, migration will skip it
# If index exists, migration will skip it (if_not_exists: true)
```

### Tests fail with database errors
```bash
# Reset test database
RAILS_ENV=test rails db:reset
RAILS_ENV=test rails db:migrate
bundle exec rspec
```

### HttpClient not found
```bash
# Restart Rails server/console to pick up autoload changes
# Or manually require in console:
require './lib/http_client'
```

## Post-Deployment Verification

1. **Check singleton constraint:**
   ```ruby
   # Rails console
   TwilioCredential.create!(account_sid: 'test', auth_token: 'test', is_singleton: true)
   # Should fail with: "Only one Twilio credential record is allowed"
   ```

2. **Test SQL injection protection:**
   ```ruby
   # Try AI assistant with safe query (should work)
   # Try AI assistant with malicious query (should be blocked)
   ```

3. **Monitor API timeouts:**
   ```ruby
   # Check circuit breaker state
   HttpClient.circuit_state
   # Should return: {} (all circuits closed initially)
   ```

## Success Criteria

- ✅ Migration runs without errors
- ✅ All 14 tests pass
- ✅ HttpClient autoloads successfully
- ✅ No Brakeman security warnings for new code
- ✅ Circuit breaker logs appear for external API calls
- ✅ No SQL injection vulnerabilities in AI assistant
- ✅ Only one TwilioCredential record with is_singleton=true can exist

## Rollback Plan

If critical issues occur:

```bash
# 1. Rollback migration
rails db:rollback

# 2. Revert code changes (if using git)
git revert HEAD

# 3. Restart application
# (varies by deployment method: systemctl, passenger, docker, etc.)
```
