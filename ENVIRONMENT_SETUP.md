# Environment Setup Guide

**Project**: Twilio Bulk Lookup
**Ruby Version Required**: 3.3.6
**Rails Version**: 7.2
**Last Updated**: December 9, 2025

---

## Table of Contents

1. [Ruby Version Manager Installation](#ruby-version-manager-installation)
2. [Ruby 3.3.6 Installation](#ruby-336-installation)
3. [Bundler and Dependencies](#bundler-and-dependencies)
4. [Database Setup](#database-setup)
5. [Redis Setup](#redis-setup)
6. [Environment Variables](#environment-variables)
7. [Running Tests](#running-tests)
8. [Troubleshooting](#troubleshooting)
9. [Development Workflow](#development-workflow)

---

## Ruby Version Manager Installation

This project requires Ruby 3.3.6. The system Ruby on macOS is 2.6.10, which is too old. You need to install a Ruby version manager.

### Option 1: rbenv (Recommended)

```bash
# Install rbenv via Homebrew
brew install rbenv ruby-build

# Add rbenv to shell (add to ~/.zshrc or ~/.bash_profile)
echo 'eval "$(rbenv init - zsh)"' >> ~/.zshrc
source ~/.zshrc

# Verify rbenv installation
rbenv -v
# Expected: rbenv 1.2.0 or higher
```

### Option 2: asdf

```bash
# Install asdf via Homebrew
brew install asdf

# Add asdf to shell
echo '. /opt/homebrew/opt/asdf/libexec/asdf.sh' >> ~/.zshrc
source ~/.zshrc

# Install Ruby plugin
asdf plugin add ruby
```

### Option 3: RVM

```bash
# Install RVM
\curl -sSL https://get.rvm.io | bash -s stable

# Load RVM into shell
source ~/.rvm/scripts/rvm

# Verify RVM installation
rvm --version
```

---

## Ruby 3.3.6 Installation

### Using rbenv

```bash
# Install Ruby 3.3.6
rbenv install 3.3.6

# Set as global Ruby version
rbenv global 3.3.6

# Verify installation
ruby --version
# Expected: ruby 3.3.6 (2024-11-05 revision ...) [arm64-darwin25]

# Verify rbenv is managing Ruby
which ruby
# Expected: /Users/YOUR_USERNAME/.rbenv/shims/ruby
```

### Using asdf

```bash
# Install Ruby 3.3.6
asdf install ruby 3.3.6

# Set as global Ruby version
asdf global ruby 3.3.6

# Verify installation
ruby --version
# Expected: ruby 3.3.6 (2024-11-05 revision ...) [arm64-darwin25]
```

### Using RVM

```bash
# Install Ruby 3.3.6
rvm install 3.3.6

# Set as default Ruby version
rvm use 3.3.6 --default

# Verify installation
ruby --version
# Expected: ruby 3.3.6 (2024-11-05 revision ...) [arm64-darwin25]
```

---

## Bundler and Dependencies

### Install Bundler 2.7.2

```bash
# Verify Ruby version first
ruby --version
# Must be 3.3.6 or higher

# Install Bundler 2.7.2 (required by Gemfile.lock)
gem install bundler:2.7.2

# Verify Bundler installation
bundle --version
# Expected: Bundler version 2.7.2

# Navigate to project directory
cd /Users/justinadams/twilio-bulk-lookup-master

# Install all gems
bundle install

# Expected output:
# Bundle complete! XX Gemfile dependencies, YY gems now installed.
# Use `bundle info [gemname]` to see where a bundled gem is installed.
```

### Troubleshooting Bundle Install

**Error: "nokogiri failed to build"**
```bash
# Install system dependencies
brew install libxml2 libxslt

# Install nokogiri with system libraries
bundle config build.nokogiri --use-system-libraries
bundle install
```

**Error: "pg gem failed to build"**
```bash
# Install PostgreSQL
brew install postgresql@15

# Add PostgreSQL to PATH
echo 'export PATH="/opt/homebrew/opt/postgresql@15/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# Retry bundle install
bundle install
```

**Error: "Permission denied"**
```bash
# Never use sudo with bundle install!
# If you see permission errors, your Ruby version manager isn't set up correctly

# Verify Ruby is managed by rbenv/asdf/rvm
which ruby
# Should NOT be /usr/bin/ruby (system Ruby)

# Should be:
# rbenv: /Users/YOUR_USERNAME/.rbenv/shims/ruby
# asdf: /Users/YOUR_USERNAME/.asdf/shims/ruby
# rvm: /Users/YOUR_USERNAME/.rvm/rubies/ruby-3.3.6/bin/ruby
```

---

## Database Setup

### Install PostgreSQL

```bash
# Install PostgreSQL 15 via Homebrew
brew install postgresql@15

# Start PostgreSQL service
brew services start postgresql@15

# Verify PostgreSQL is running
psql --version
# Expected: psql (PostgreSQL) 15.x

# Test connection
psql postgres
# Should connect successfully
# Type \q to exit
```

### Create Database

```bash
# Create development database
RAILS_ENV=development rails db:create

# Run migrations
RAILS_ENV=development rails db:migrate

# Verify migrations
RAILS_ENV=development rails db:migrate:status
# Expected: All migrations should show "up"

# Create test database
RAILS_ENV=test rails db:create
RAILS_ENV=test rails db:migrate

# Verify idempotency_key column exists
RAILS_ENV=test rails runner "puts Webhook.column_names.include?('idempotency_key')"
# Expected: true
```

### Database Configuration

Check `config/database.yml`:

```yaml
development:
  adapter: postgresql
  encoding: unicode
  database: twilio_bulk_lookup_development
  pool: 5
  username: <%= ENV['DATABASE_USERNAME'] || `whoami`.strip %>
  password: <%= ENV['DATABASE_PASSWORD'] %>
  host: localhost

test:
  adapter: postgresql
  encoding: unicode
  database: twilio_bulk_lookup_test
  pool: 5
  username: <%= ENV['DATABASE_USERNAME'] || `whoami`.strip %>
  password: <%= ENV['DATABASE_PASSWORD'] %>
  host: localhost
```

---

## Redis Setup

### Install Redis

```bash
# Install Redis via Homebrew
brew install redis

# Start Redis service
brew services start redis

# Verify Redis is running
redis-cli ping
# Expected: PONG

# Check Redis version
redis-server --version
# Expected: Redis server v=7.x or higher
```

### Test Redis Connection

```bash
# Open Redis CLI
redis-cli

# Test basic commands
127.0.0.1:6379> SET test "Hello Redis"
# Expected: OK

127.0.0.1:6379> GET test
# Expected: "Hello Redis"

127.0.0.1:6379> DEL test
# Expected: (integer) 1

127.0.0.1:6379> EXIT
```

### Redis Configuration for Rails

Redis is used for:
- **Sidekiq background jobs** (job queue)
- **Rails.cache** (circuit breaker state, session storage)
- **Action Cable** (WebSocket connections, if enabled)

Default Redis URL: `redis://localhost:6379/0`

To customize, set environment variable:
```bash
export REDIS_URL=redis://localhost:6379/0
```

---

## Environment Variables

### Required Environment Variables

Create `.env` file in project root:

```bash
# Copy example file
cp .env.example .env

# Edit with your values
nano .env
```

**Minimum required variables**:

```bash
# Database
DATABASE_USERNAME=your_username
DATABASE_PASSWORD=your_password  # Leave blank if no password

# Redis
REDIS_URL=redis://localhost:6379/0

# Rails
RAILS_ENV=development
SECRET_KEY_BASE=your_secret_key_base  # Generate with: rails secret

# Twilio (required for core functionality)
TWILIO_ACCOUNT_SID=your_account_sid
TWILIO_AUTH_TOKEN=your_auth_token

# Optional: External API keys (for enrichment features)
CLEARBIT_API_KEY=your_clearbit_key
NUMVERIFY_API_KEY=your_numverify_key
OPENAI_API_KEY=your_openai_key
```

### Generate SECRET_KEY_BASE

```bash
# Generate new secret key
rails secret

# Copy output to .env file
# SECRET_KEY_BASE=a1b2c3d4e5f6...
```

---

## Running Tests

### Unit Tests (Phase 3)

```bash
# Run all new unit tests
bundle exec rspec spec/services/prompt_sanitizer_spec.rb \
                    spec/models/contact_bulk_operations_spec.rb \
                    spec/models/webhook_idempotency_spec.rb \
                    spec/lib/http_client_spec.rb \
                    --format documentation

# Expected output:
# PromptSanitizer
#   .sanitize
#     with injection attempts
#       blocks "Ignore all previous instructions" pattern
#       [... 30+ tests ...]
#
# Contact bulk operations
#   .with_callbacks_skipped
#     skips fingerprint calculation callbacks during bulk import
#     [... 15+ tests ...]
#
# [... 90+ tests total ...]
#
# Finished in X.XX seconds
# 90 examples, 0 failures
```

### Integration Tests (Phase 4)

```bash
# Run all integration tests
bundle exec rspec spec/integration/ --format documentation

# Expected output:
# Bulk import workflow with metric recalculation
#   bulk import with callbacks skipped + background recalculation
#     imports 1000 contacts efficiently, then recalculates metrics via background job
#     [... 10+ tests ...]
#
# Webhook replay attack protection
#   POST /webhooks/twilio_sms_status
#     accepts first webhook POST and processes it
#     rejects duplicate webhook POST (replay attack)
#     [... 20+ tests ...]
#
# Circuit breaker during API outages
#   API outage scenario
#     short-circuits requests after 5 failures, conserves API credits
#     [... 15+ tests ...]
#
# Finished in X.XX seconds
# 45+ examples, 0 failures
```

### Controller Tests

```bash
# Run webhook controller tests
bundle exec rspec spec/controllers/webhooks_controller_spec.rb --format documentation

# Expected output:
# WebhooksController
#   POST #twilio_sms_status
#     with valid params
#       creates webhook and returns 200 OK
#       [... 20+ tests ...]
#
# Finished in X.XX seconds
# 20+ examples, 0 failures
```

### Run All Tests

```bash
# Run entire test suite
bundle exec rspec

# With parallel execution (faster)
gem install parallel_tests
parallel_rspec spec/ -n 4  # 4 parallel processes

# With coverage report
COVERAGE=true bundle exec rspec
open coverage/index.html
```

### Test Performance

```bash
# Run tests with profiling
bundle exec rspec --profile 10

# Expected output shows slowest 10 tests
# Top 10 slowest examples (XX seconds, XX% of total time):
#   imports 1000 contacts efficiently... (5.23 seconds)
#   recalculation processes 1000 contacts... (3.45 seconds)
#   [...]
```

---

## Troubleshooting

### Issue: "Could not find 'bundler' (2.7.2)"

**Cause**: Wrong Ruby version or Bundler not installed

**Solution**:
```bash
# Verify Ruby version
ruby --version
# Must be 3.3.6 or higher

# Install Bundler 2.7.2
gem install bundler:2.7.2

# Verify
bundle --version
# Expected: Bundler version 2.7.2
```

### Issue: "PG::ConnectionBad - could not connect to server"

**Cause**: PostgreSQL not running

**Solution**:
```bash
# Start PostgreSQL
brew services start postgresql@15

# Verify
psql postgres
# Should connect
```

### Issue: "Redis::CannotConnectError"

**Cause**: Redis not running

**Solution**:
```bash
# Start Redis
brew services start redis

# Verify
redis-cli ping
# Expected: PONG
```

### Issue: "LoadError: cannot load such file -- webmock"

**Cause**: Test dependencies not installed

**Solution**:
```bash
# Install all development/test dependencies
bundle install --with development test

# Or install specific gem
gem install webmock
bundle install
```

### Issue: Tests fail with "ActiveRecord::PendingMigrationError"

**Cause**: Test database migrations not run

**Solution**:
```bash
# Run test migrations
RAILS_ENV=test rails db:migrate

# Verify
RAILS_ENV=test rails db:migrate:status
```

### Issue: "Errno::EADDRINUSE - Address already in use - bind(2)"

**Cause**: Rails server or Sidekiq already running on port 3000

**Solution**:
```bash
# Find process using port 3000
lsof -ti:3000

# Kill process
kill -9 $(lsof -ti:3000)

# Or use different port
rails server -p 3001
```

---

## Development Workflow

### Starting Development Environment

```bash
# Terminal 1: Start Rails server
rails server

# Terminal 2: Start Sidekiq (background jobs)
bundle exec sidekiq

# Terminal 3: Rails console (for debugging)
rails console

# Terminal 4: Tail logs
tail -f log/development.log
```

### Running Migrations

```bash
# Create new migration
rails generate migration AddColumnToTable column_name:data_type

# Run migrations
rails db:migrate

# Rollback last migration
rails db:rollback

# Check migration status
rails db:migrate:status
```

### Database Console

```bash
# PostgreSQL console
rails dbconsole

# Or directly via psql
psql twilio_bulk_lookup_development
```

### Redis Console

```bash
# Redis CLI
redis-cli

# View all keys
KEYS *

# View circuit breaker state
GET circuit_breaker:clearbit

# Clear all keys (WARNING: Clears all data!)
FLUSHALL
```

### Code Quality Checks

```bash
# Lint Ruby code
bundle exec rubocop

# Auto-fix safe issues
bundle exec rubocop -a

# Security audit
bundle exec brakeman

# Dependency audit
bundle audit check --update
```

---

## Quick Start (New Machine Setup)

```bash
# 1. Install rbenv
brew install rbenv ruby-build

# 2. Configure shell
echo 'eval "$(rbenv init - zsh)"' >> ~/.zshrc
source ~/.zshrc

# 3. Install Ruby 3.3.6
rbenv install 3.3.6
rbenv global 3.3.6

# 4. Verify Ruby
ruby --version  # Should be 3.3.6

# 5. Install Bundler
gem install bundler:2.7.2

# 6. Install dependencies
brew install postgresql@15 redis
brew services start postgresql@15
brew services start redis

# 7. Clone and setup project
cd /Users/justinadams/twilio-bulk-lookup-master
bundle install
cp .env.example .env
# Edit .env with your credentials

# 8. Setup databases
RAILS_ENV=development rails db:create db:migrate
RAILS_ENV=test rails db:create db:migrate

# 9. Run tests
bundle exec rspec

# 10. Start development
rails server  # Terminal 1
bundle exec sidekiq  # Terminal 2
```

---

## Production Deployment Checklist

Before deploying to production:

- [ ] Ruby 3.3.6 installed on production server
- [ ] Bundler 2.7.2 installed
- [ ] PostgreSQL 15+ configured
- [ ] Redis 7+ configured
- [ ] All environment variables set in production
- [ ] Database migrations run: `RAILS_ENV=production rails db:migrate`
- [ ] Assets precompiled: `RAILS_ENV=production rails assets:precompile`
- [ ] Security headers configured (already done in Phase 2)
- [ ] Rate limiting configured (already done in Phase 2)
- [ ] Log sanitization enabled (already done in Phase 2)
- [ ] Circuit breaker tested with production API keys
- [ ] Webhook idempotency migration run (20251209162216)
- [ ] Test suite passing: `RAILS_ENV=test bundle exec rspec`
- [ ] Sidekiq workers started: `bundle exec sidekiq -C config/sidekiq.yml`
- [ ] Monitoring configured (DataDog, New Relic, or similar)
- [ ] Error tracking configured (Sentry, Rollbar, or similar)
- [ ] Backups configured for PostgreSQL and Redis

---

## Additional Resources

### Documentation
- **Ruby 3.3.6**: https://www.ruby-lang.org/en/news/2024/11/05/ruby-3-3-6-released/
- **Rails 7.2**: https://guides.rubyonrails.org/
- **rbenv**: https://github.com/rbenv/rbenv
- **PostgreSQL**: https://www.postgresql.org/docs/15/
- **Redis**: https://redis.io/docs/

### Project Documentation
- **CRITICAL_FIXES_COMPLETE.md**: Phase 1 security fixes
- **SECURITY_HARDENING_COMPLETE.md**: Phase 2 infrastructure security
- **TEST_COVERAGE_COMPLETE.md**: Phase 3 unit tests
- **CLAUDE.md**: Darwin-Gödel framework and project guidelines
- **ULTRA_DEEP_ANALYSIS.md**: Security audit findings

### Support
- **GitHub Issues**: https://github.com/anthropics/claude-code/issues
- **Twilio Docs**: https://www.twilio.com/docs
- **Stack Overflow**: Tag with `ruby`, `rails`, `twilio`

---

**Last Updated**: December 9, 2025
**Maintained By**: Darwin-Gödel Framework (Claude Sonnet 4.5)
