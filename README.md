> NOT SUPPORTED OR MAINTAINED BY TWILIO, USE AT YOUR OWN RISK.

# Bulk Lookup for Twilio

Twilio Lookup allows you to determine if a phone number is a mobile number or a landline. This project allows you to upload a CSV, run a bulk lookup, and then download a CSV with information from the Lookup API.

## 🚀 Features

- **Bulk Phone Number Lookup**: Process thousands of phone numbers via Twilio Lookup API
- **CSV Import/Export**: Easy data import and export in CSV, TSV, or Excel formats
- **Background Processing**: Sidekiq-powered async job processing with Redis
- **Admin Interface**: ActiveAdmin dashboard for managing contacts and credentials
- **Status Tracking**: Real-time processing status for all contacts
- **Error Handling**: Intelligent retry logic with exponential backoff
- **Rate Limiting**: Configurable concurrency to prevent API throttling
- **Idempotency**: Skip already-processed contacts automatically
- **Monitoring Dashboard**: Built-in Sidekiq Web UI for job monitoring

## 📋 Prerequisites

Before you start, you'll need:

* A [Twilio Account](https://twilio.com/try-twilio) with API credentials
* Ruby 3.3.5 (use [rbenv](https://github.com/rbenv/rbenv) or [rvm](https://rvm.io/))
* PostgreSQL 9.1+
* Redis (for background job processing)

## 🏗️ Local Setup

### 1. Clone and Install Dependencies

```bash
# Clone the repository
git clone git@github.com:cweems/twilio-bulk-lookup.git
cd twilio-bulk-lookup

# Install Ruby 3.3.5 (using rbenv)
rbenv install 3.3.5
rbenv local 3.3.5

# Install dependencies
bundle install
```

### 2. Install and Start Redis

```bash
# macOS (using Homebrew)
brew install redis
brew services start redis

# Ubuntu/Debian
sudo apt-get install redis-server
sudo systemctl start redis-server

# Verify Redis is running
redis-cli ping  # Should return "PONG"
```

### 3. Database Setup

```bash
# Create and migrate database
rails db:create
rails db:migrate
rails db:seed

# The seed creates a default admin user:
# Email: admin@example.com
# Password: password
```

### 4. Configure Twilio Credentials

**Option A: Environment Variables (Recommended for Production)**

```bash
# Add to .env file or export directly
export TWILIO_ACCOUNT_SID='ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
export TWILIO_AUTH_TOKEN='your_auth_token_here'
export REDIS_URL='redis://localhost:6379/0'
```

**Option B: Rails Encrypted Credentials**

```bash
# Edit credentials file
EDITOR="code --wait" rails credentials:edit

# Add these lines:
twilio:
  account_sid: ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  auth_token: your_auth_token_here
```

**Option C: Admin Interface (Development Only)**

After starting the app, log in and navigate to "Twilio Credentials" in the admin panel.

⚠️ **Security Note**: For production, use environment variables or Rails encrypted credentials instead of storing in the database.

### 5. Start the Application

You'll need **three terminal windows**:

**Terminal 1 - Rails Server:**
```bash
rails server
```

**Terminal 2 - Sidekiq Worker:**
```bash
bundle exec sidekiq -C config/sidekiq.yml
```

**Terminal 3 - Redis (if not running as service):**
```bash
redis-server
```

### 6. Access the Application

- **Main App**: http://localhost:3000
- **Admin Dashboard**: http://localhost:3000/admin
- **Sidekiq Monitor**: http://localhost:3000/sidekiq (requires admin login)

Default admin credentials (from seed):
- Email: `admin@example.com`
- Password: `password`

## 📊 Usage

### Import Contacts

1. Log in to the admin dashboard
2. Navigate to **Contacts**
3. Click **Import Contacts**
4. Upload a CSV file with phone numbers (column: `raw_phone_number`)

Example CSV format:
```csv
raw_phone_number
+14155551234
+14155555678
+14155559999
```

### Run Bulk Lookup

1. Go to the **Dashboard**
2. Click **Run Lookup** button
3. Processing will happen in the background via Sidekiq
4. Monitor progress in the Dashboard or Sidekiq UI

### Monitor Progress

- **Dashboard**: Shows total contacts and processed count
- **Sidekiq UI** (`/sidekiq`): Real-time job monitoring, retries, failures
- **Contacts Page**: Filter by status (pending/processing/completed/failed)

### Export Results

1. Navigate to **Contacts**
2. Use filters to select desired contacts
3. Click **Download** and choose format (CSV/TSV/Excel)

Exported data includes:
- Original phone number
- Formatted phone number
- Carrier name
- Device type (mobile/landline/voip)
- Mobile network/country codes
- Processing status
- Error messages (if failed)

## ⚙️ Configuration

### Sidekiq Concurrency

Edit `config/sidekiq.yml` to adjust processing speed:

```yaml
:concurrency: 5  # Number of parallel jobs (default: 5)
```

**Recommendations:**
- **Development**: 2-5 workers
- **Production**: 10-20 workers (monitor API rate limits)
- Lower concurrency if hitting rate limits
- Higher concurrency for faster processing

### Processing Rate

With default settings (concurrency: 5):
- **Theoretical max**: ~25 requests/second
- **Realistic throughput**: ~4,000 contacts/hour
- Actual rate depends on network latency and API response time

### Retry Configuration

Jobs automatically retry on transient failures:
- **Max retries**: 3 attempts
- **Backoff**: Exponential (15s, 17s, 19s)
- **Permanent failures**: No retry (invalid numbers, auth errors)

## 🔧 Heroku Deployment

[![Deploy](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy)

### Manual Heroku Setup

```bash
# Create Heroku app
heroku create your-app-name

# Add PostgreSQL
heroku addons:create heroku-postgresql:mini

# Add Redis
heroku addons:create heroku-redis:mini

# Set Twilio credentials
heroku config:set TWILIO_ACCOUNT_SID='ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
heroku config:set TWILIO_AUTH_TOKEN='your_auth_token_here'

# Deploy
git push heroku main

# Run migrations
heroku run rails db:migrate
heroku run rails db:seed

# Create admin user
heroku run rails console
> AdminUser.create(email: 'your_email@mail.com', password: 'your_secure_password', password_confirmation: 'your_secure_password')
```

## 🛡️ Security Best Practices

1. **Never commit credentials** to version control
2. **Use environment variables** for production credentials
3. **Change default admin password** immediately
4. **Enable HTTPS** in production (Heroku provides this automatically)
5. **Regularly rotate** API credentials
6. **Monitor** Sidekiq dashboard for unusual activity

## 🔍 Troubleshooting

### Jobs Not Processing

```bash
# Check Redis connection
redis-cli ping

# Check Sidekiq is running
ps aux | grep sidekiq

# View Sidekiq logs
tail -f log/sidekiq.log

# Restart Sidekiq
# Stop current process (Ctrl+C) and restart:
bundle exec sidekiq -C config/sidekiq.yml
```

### Database Issues

```bash
# Reset database (⚠️ deletes all data)
rails db:drop db:create db:migrate db:seed

# Check migrations
rails db:migrate:status
```

### API Errors

- **Authentication Failed**: Verify `TWILIO_ACCOUNT_SID` and `TWILIO_AUTH_TOKEN`
- **Rate Limit Exceeded**: Lower Sidekiq concurrency in `config/sidekiq.yml`
- **Invalid Number**: Check phone number format (E.164 recommended: +1234567890)

## 📝 API Response Fields

| Field | Description | Example |
|-------|-------------|---------|
| `raw_phone_number` | Original input | `4155551234` |
| `formatted_phone_number` | E.164 format | `+14155551234` |
| `carrier_name` | Carrier/provider name | `Verizon` |
| `device_type` | Phone type | `mobile`, `landline`, `voip` |
| `mobile_country_code` | MCC code | `310` |
| `mobile_network_code` | MNC code | `456` |
| `error_code` | Error message if failed | `Invalid number format` |
| `status` | Processing status | `pending`, `processing`, `completed`, `failed` |

## 🧪 Development

### Running Tests

```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/models/contact_spec.rb

# Run with coverage report
COVERAGE=true bundle exec rspec
```

### Code Quality

```bash
# Run RuboCop linter
bundle exec rubocop

# Auto-fix safe issues
bundle exec rubocop -a

# Security audit
bundle exec brakeman
```

### Console Access

```bash
# Local
rails console

# Heroku
heroku run rails console
```

## 📚 Additional Resources

- [Twilio Lookup API Documentation](https://www.twilio.com/docs/lookup/api)
- [Sidekiq Documentation](https://github.com/sidekiq/sidekiq/wiki)
- [ActiveAdmin Documentation](https://activeadmin.info/documentation.html)
- [Rails Guides](https://guides.rubyonrails.org/)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

See [LICENSE](LICENSE) file for details.

## ⚠️ Disclaimer

This project is not officially supported or maintained by Twilio. Use at your own risk.