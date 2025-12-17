# Technology Stack

## Core Framework
- Ruby 3.3.6
- Rails 7.2
- PostgreSQL 9.1+

## Background Processing
- Sidekiq 7.x with Redis
- Concurrent job processing with configurable concurrency

## Admin Interface
- ActiveAdmin 3.2 with Devise authentication
- Kaminari for pagination
- Ransack for search/filtering

## API Integrations
- twilio-ruby ~> 7.2 (Twilio SDK)
- HTTParty and Faraday for HTTP clients
- Circuit breaker pattern via Stoplight gem

## Frontend
- Sprockets asset pipeline
- SCSS stylesheets
- Turbo Rails and Stimulus for JavaScript

## Monitoring & Error Tracking
- Sentry (sentry-rails, sentry-ruby)
- Rack::Attack for rate limiting
- Custom request logging middleware

## Testing
- RSpec with FactoryBot
- WebMock for HTTP stubbing
- SimpleCov for coverage
- Capybara + Selenium for system tests

---

## Common Commands

### Development
```bash
# Start Rails server
rails server

# Start Sidekiq worker
bundle exec sidekiq -C config/sidekiq.yml

# Start Redis (if not running as service)
redis-server
```

### Database
```bash
rails db:create db:migrate db:seed
rails db:migrate:status
rails db:drop db:create db:migrate db:seed  # Full reset
```

### Testing
```bash
bundle exec rspec                           # Run all specs
bundle exec rspec spec/models/              # Run model specs
bundle exec rspec spec/path/to/spec.rb      # Run specific file
COVERAGE=true bundle exec rspec             # With coverage report
```

### Code Quality
```bash
bundle exec rubocop                         # Linting
bundle exec rubocop -a                      # Auto-fix safe issues
bundle exec brakeman                        # Security audit
```

### Maintenance Tasks
```bash
rake maintenance:circuit_breakers           # Show circuit breaker status
rake maintenance:reset_circuits             # Reset all circuit breakers
rake maintenance:health_check               # CLI health check
rake maintenance:clear_cache                # Clear all caches
rake maintenance:diagnostics                # Full system diagnostics
```

### Console
```bash
rails console                               # Local
heroku run rails console                    # Heroku
```
