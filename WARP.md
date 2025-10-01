# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

This is a Rails application for performing bulk phone number lookups using the Twilio Lookup API. It allows users to:
- Upload CSV files of phone numbers via ActiveAdmin interface
- Process phone numbers asynchronously via Sidekiq background jobs
- Export lookup results as CSV/TSV/Excel files

The application uses:
- Rails 7.2 with Ruby 3.3.5 (managed via rbenv)
- ActiveAdmin 3.3 for the admin interface with user authentication via Devise
- Sidekiq 7.3 with Redis for background job processing
- PostgreSQL 17 as the database
- Twilio Ruby SDK 7.8 for API integration
- Modern development tools: RuboCop, Brakeman, RSpec

## Common Development Commands

### Prerequisites
- Ruby 3.3.5 (managed via rbenv)
- PostgreSQL 17 (install via `brew install postgresql@17`)
- Redis (install via `brew install redis`)

### Initial Setup
```bash
# Install Ruby via rbenv (if not already installed)
rbenv install 3.3.5
rbenv local 3.3.5

# Install Ruby dependencies
bundle install

# Start PostgreSQL
brew services start postgresql@17

# Set up database
rails db:create
rails db:migrate
rails db:seed

# Start Redis (required for Sidekiq)
brew services start redis  # Or redis-server in separate terminal

# Start Sidekiq worker
bundle exec sidekiq -c 2  # In separate terminal

# Start Rails server
rails s
```

### Development Workflow
```bash
# Run Rails server in debug mode
env RUBY_DEBUG_OPEN=true bin/rails server

# Run console
rails console

# Run migrations
rails db:migrate

# Reset database (development only)
rails db:drop db:create db:migrate db:seed

# Check routes
rails routes

# Run tests (Rails default)
rails test

# Run RSpec tests (if using RSpec)
rspec

# Code quality and linting
bundle exec rubocop                    # Run linter
bundle exec rubocop -a                # Auto-fix issues
bundle exec brakeman                   # Security analysis

# Check for outdated gems
bundle outdated
```

### Background Jobs
```bash
# Monitor Sidekiq queue
bundle exec sidekiq -c 2

# Start Sidekiq with specific concurrency
bundle exec sidekiq -c [number]
```

## Application Architecture

### Core Models
- **Contact**: Stores phone numbers and lookup results (raw_phone_number, formatted_phone_number, carrier info, error_code)
- **TwilioCredential**: Stores Twilio Account SID and Auth Token (single record expected)
- **AdminUser**: Devise-based authentication for admin interface

### Key Components
- **LookupRequestJob**: Sidekiq job that performs individual Twilio API calls for phone number lookup
- **ActiveAdmin Resources**: Admin interface for contacts, credentials, and dashboard with bulk operations
- **LookupController**: Triggers bulk lookup by enqueueing jobs for all contacts

### Data Flow
1. Admin uploads CSV of phone numbers via ActiveAdmin import
2. User triggers bulk lookup from dashboard
3. LookupController enqueues LookupRequestJob for each contact
4. Background jobs call Twilio Lookup API and update contact records
5. Results exported via ActiveAdmin interface

### Deployment Configuration
- **Procfile**: Defines web (Puma), apiworker (Sidekiq), and release processes for Heroku
- **Procfile.dev**: Development setup with Rails server and CSS watching

## Testing

The application uses Rails' built-in testing framework. Test files are located in:
- `test/` directory with basic setup files
- Uses Capybara and Selenium for system testing

## Database Schema

Key tables:
- `contacts`: Phone number data and lookup results
- `twilio_credentials`: API credentials (Account SID, Auth Token)
- `admin_users`: Devise authentication
- `active_admin_comments`: Admin interface comments

## Environment Setup

### Required Services
- PostgreSQL database
- Redis server (for Sidekiq)
- Twilio account with API credentials

### Seeded Data
Running `rake db:seed` creates a default admin user:
- Email: admin@example.com
- Password: password

### Ruby Version
The application requires Ruby 3.3.5 (specified in Gemfile and .ruby-version)
