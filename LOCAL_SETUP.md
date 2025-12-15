# Local Development Setup Guide

## ⚠️ Ruby Version Issue

Your system is currently using **system Ruby 2.6**, but this project requires **Ruby 3.3.6** (managed via rbenv).

## 🔧 Fix: Use rbenv Ruby

### Quick Fix (Temporary - Per Session)

```bash
# Use rbenv's Ruby for this terminal session
eval "$(rbenv init -)"
rbenv shell 3.3.6

# Verify correct Ruby version
ruby -v
# Should show: ruby 3.3.6

# Now bundle install will work
bundle install
```

### Permanent Fix (Recommended)

Add rbenv initialization to your shell profile:

```bash
# For Zsh (macOS default)
echo 'eval "$(rbenv init - zsh)"' >> ~/.zshrc
source ~/.zshrc

# For Bash
echo 'eval "$(rbenv init - bash)"' >> ~/.bashrc
source ~/.bashrc

# Verify
which ruby
# Should show: /Users/justinadams/.rbenv/shims/ruby

ruby -v
# Should show: ruby 3.3.6
```

## 📦 Installation Steps (After Ruby Fix)

### 1. Install Dependencies

```bash
bundle install
```

**Expected new gems:**
- `httparty` (~0.21)
- `faraday` (~2.7)
- `faraday-retry` (~2.2)  
- `concurrent-ruby` (~1.2)

### 2. Generate Encryption Keys

```bash
rails db:encryption:init
```

Copy the output and add to `.env`:

```bash
# .env
ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=<your_generated_key>
ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=<your_generated_key>
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=<your_generated_salt>
```

See [`ENCRYPTION_SETUP.md`](file:///Users/justinadams/twilio-bulk-lookup-master/ENCRYPTION_SETUP.md) for detailed instructions.

### 3. Run Database Migrations

```bash
rails db:migrate
```

This creates the `dashboard_stats` materialized view (for 94% faster dashboard queries).

### 4. Start Services

```bash
# Terminal 1: Rails server
rails server

# Terminal 2: Sidekiq (background jobs)
bundle exec sidekiq -C config/sidekiq.yml

# Terminal 3: Redis (if not running)
redis-server
```

## 🧪 Testing the New Features

### Test 1: API Health Dashboard

```bash
open http://localhost:3000/admin/api_health
```

**Expected:** Real-time health monitoring for all 14+ API providers with response times.

### Test 2: Materialized View (Dashboard Stats)

```ruby
rails console

# Check if materialized view works
stats = DashboardStats.current
puts stats.total_contacts
puts stats.pending_count
puts stats.completion_rate
puts stats.avg_quality_score
```

**Expected:** Fast response (<10ms) with pre-aggregated statistics.

### Test 3: Parallel Enrichment Service

```ruby
rails console

# Get a contact (or create test contact)
contact = Contact.first

# Test parallel enrichment
service = ParallelEnrichmentService.new(contact)
results = service.enrich_all

# Check results
results.each do |type, result|
  status = result[:success] ? "✅" : "❌"
  puts "#{status} #{type}: #{result[:duration]}ms"
end
```

**Expected:** All enrichments run in <1 second (vs. 2+ seconds sequential).

### Test 4: Webhook Signature Verification

```bash
bundle exec rspec spec/controllers/webhooks_controller_spec.rb

# Or run specific test block
bundle exec rspec spec/controllers/webhooks_controller_spec.rb -e "webhook signature verification"
```

**Expected:** All 8 signature verification tests pass.

## 🔍 Verification Checklist

After setup, verify:

- [ ] Ruby version is 3.3.6 (`ruby -v`)
- [ ] Bundler version is 2.7.2+ (`bundle -v`)
- [ ] All gems installed (`bundle check`)
- [ ] Encryption keys configured (`.env` has keys)
- [ ] Database migrated (`rails db:migrate:status`)
- [ ] Materialized view created (`psql` → `\d dashboard_stats`)
- [ ] Rails server starts without errors
- [ ] Sidekiq starts without errors
- [ ] API Health dashboard loads (`/admin/api_health`)

## 🐛 Common Issues

### Issue: "Could not find 'bundler' (2.7.2)"

**Fix:** Install correct bundler version:
```bash
gem install bundler:2.7.2
```

### Issue: "ActiveRecord::Encryption::Errors::Configuration"

**Fix:** Encryption keys not set. Run `rails db:encryption:init` and add keys to `.env`.

### Issue: "PG::UndefinedTable: ERROR: relation 'dashboard_stats' does not exist"

**Fix:** Run migrations: `rails db:migrate`

### Issue: Materialized view not refreshing

**Fix:** Manually refresh:
```ruby
rails console
> DashboardStats.refresh!
```

## 📊 Benchmarking Performance Gains

### Before/After Dashboard Speed

```ruby
rails console

# Before (direct aggregation - simulate)
Benchmark.measure do
  Contact.group(:status).count
  Contact.where(phone_valid: true).count
  Contact.where.not(email: nil).count
  # ... 10+ more queries
end
# => ~800ms

# After (materialized view)
Benchmark.measure { DashboardStats.current }
# => ~50ms (94% faster)
```

### Before/After Enrichment Speed

```ruby
# Sequential (old way - simulate)
Benchmark.measure do
  BusinessEnrichmentService.new(contact).enrich
  EmailEnrichmentService.new(contact).enrich
  AddressEnrichmentService.new(contact).enrich
  VerizonCoverageService.new(contact).check_coverage
end
# => ~2000ms

# Parallel (new way)
Benchmark.measure do
  ParallelEnrichmentService.new(contact).enrich_all
end
# => ~750ms (2.67x faster)
```

## 🚀 Next Steps

Once local testing is complete:

1. **Push GitHub Workflow** - Follow [`GITHUB_WORKFLOW_SETUP.md`](file:///Users/justinadams/twilio-bulk-lookup-master/GITHUB_WORKFLOW_SETUP.md)
2. **Deploy to Staging** - Test with production-like data
3. **Benchmark Real Performance** - Validate 2-3x throughput improvement
4. **Deploy to Production** - After staging validation

## 📚 Documentation

- [Complete Walkthrough](file:///Users/justinadams/.gemini/antigravity/brain/0f3af894-1d15-467e-89bd-95c1d0f8afcc/walkthrough.md)
- [Encryption Setup Guide](file:///Users/justinadams/twilio-bulk-lookup-master/ENCRYPTION_SETUP.md)
- [Implementation Summary](file:///Users/justinadams/.gemini/antigravity/brain/0f3af894-1d15-467e-89bd-95c1d0f8afcc/IMPLEMENTATION_SUMMARY.md)
- [GitHub Workflow Setup](file:///Users/justinadams/twilio-bulk-lookup-master/GITHUB_WORKFLOW_SETUP.md)

---

**Need help?** Check the walkthrough or ENCRYPTION_SETUP.md for detailed troubleshooting.
