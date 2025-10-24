> NOT SUPPORTED OR MAINTAINED BY TWILIO, USE AT YOUR OWN RISK.

# 📞 Bulk Lookup for Twilio

[![Ruby](https://img.shields.io/badge/Ruby-3.3.6-red.svg)](https://www.ruby-lang.org/)
[![Rails](https://img.shields.io/badge/Rails-7.2-red.svg)](https://rubyonrails.org/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Docker](https://img.shields.io/badge/Docker-Ready-blue.svg)](https://www.docker.com/)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

An enterprise-grade contact enrichment platform powered by Twilio Lookup API and 14+ data providers. Go beyond basic phone validation with business intelligence, email enrichment, multi-LLM AI support, CRM sync, automated messaging, and comprehensive contact management.

---

## 🚀 Quick Start

> **New to this project?** → Start with [**START_HERE.md**](START_HERE.md) 🎯

**Want to get started immediately?** See [**QUICK_START.md**](QUICK_START.md) for a 3-step setup guide!

```bash
# 1. Copy environment file
cp .env.example .env

# 2. Add your Twilio credentials to .env, then:
bash start.sh  # Start with Docker

# OR
docker-compose up --build -d
```

**Access**: http://localhost:3002/admin  
**Login**: admin@example.com / password  
**Monitor**: http://localhost:3002/sidekiq

---

## ✨ What's New in v2.0

This platform has evolved from a simple phone lookup tool into a comprehensive contact intelligence system with enterprise features:

- **🆕 Multi-LLM Support**: OpenAI GPT, Anthropic Claude, and Google Gemini integration
- **🆕 CRM Sync**: Bidirectional sync with Salesforce, HubSpot, and Pipedrive
- **🆕 SMS & Voice**: Automated outreach with Twilio messaging and voice calls
- **🆕 Geocoding**: Google Maps integration for address-to-coordinates conversion
- **🆕 Real-time Webhooks**: Live status updates for Trust Hub, SMS, and voice calls
- **🆕 API Cost Tracking**: Per-API usage analytics and billing insights
- **API Connectors Dashboard**: Manage 14+ data providers from a single interface
- **Business Discovery**: Find and import businesses by zipcode using Google Places and Yelp
- **AI-Powered Search**: Query your contacts using natural language with multiple LLM providers
- **Advanced Enrichment**: Business data, email discovery, address lookup, geocoding, and more
- **Trust Hub Integration**: Business verification through Twilio Trust Hub with real-time webhooks
- **Verizon Coverage**: Check 5G/LTE Home Internet availability with geocoded precision
- **Quality Metrics**: Automated data quality scoring and tracking
- **Duplicate Detection**: Smart contact deduplication

## 🚀 Features

### Core Functionality
- **Bulk Phone Number Lookup**: Process thousands of phone numbers via Twilio Lookup v2 API
- **14+ API Integrations**: Unified dashboard for managing multiple data providers
- **CSV Import/Export**: Easy data import and export in CSV, TSV, or Excel formats
- **Background Processing**: Sidekiq-powered async job processing with Redis
- **Admin Interface**: Comprehensive ActiveAdmin dashboard
- **Status Tracking**: Real-time processing status for all contacts with webhook updates
- **Error Handling**: Intelligent retry logic with exponential backoff
- **Rate Limiting**: Configurable concurrency to prevent API throttling
- **Idempotency**: Skip already-processed contacts automatically
- **🆕 API Cost Tracking**: Real-time cost analytics per provider with usage insights
- **🆕 Webhook System**: Real-time status updates for SMS, voice calls, and Trust Hub

### Advanced Enrichment
- **Business Intelligence**: Company data from Clearbit and NumVerify
- **Email Discovery**: Find and verify emails with Hunter.io and ZeroBounce
- **Address Enrichment**: Consumer addresses via Whitepages Pro and TrueCaller
- **🆕 Geocoding**: Convert addresses to coordinates using Google Geocoding API
- **Business Directory**: Zipcode-based business lookup via Google Places and Yelp
- **Verizon Coverage**: Check 5G/LTE Home Internet availability (enhanced with geocoding)
- **Duplicate Detection**: Automatic duplicate contact identification
- **Trust Hub Integration**: Business verification via Twilio Trust Hub with real-time webhooks

### AI-Powered Features
- **🆕 Multi-LLM Support**: Choose between OpenAI GPT, Anthropic Claude, or Google Gemini
- **Natural Language Search**: Query contacts using plain English
- **AI Assistant**: Get insights and recommendations from your data
- **Smart Filtering**: AI-powered contact segmentation
- **Sales Intelligence**: Automated lead scoring and analysis
- **🆕 Outreach Generation**: AI-powered SMS and email message creation
- **Cost Optimization**: Automatic selection of most cost-effective LLM for each task

### Data Quality
- **Line Type Intelligence**: Mobile, landline, VoIP detection
- **Caller Name (CNAM)**: Identify phone line owners
- **SMS Pumping Risk**: Fraud detection and risk scoring
- **SIM Swap Detection**: Security threat identification
- **Reassigned Number**: Detect recycled phone numbers
- **Quality Scoring**: Automated data quality metrics

## 🏗️ Architecture

### Technology Stack
- **Backend**: Ruby on Rails 7.x
- **Database**: PostgreSQL 9.1+
- **Background Jobs**: Sidekiq with Redis
- **Admin Interface**: ActiveAdmin
- **API Integration**: 14+ third-party providers
- **AI/ML**: OpenAI GPT, Anthropic Claude, Google Gemini
- **Messaging**: Twilio SMS & Voice API
- **CRM Integration**: Salesforce, HubSpot, Pipedrive
- **Geocoding**: Google Maps Geocoding API
- **Frontend**: Responsive admin dashboard with real-time updates

### Key Components

**API Connectors Dashboard**
- Unified view of all API integrations
- Real-time connection health checks
- Per-API configuration and status
- Usage statistics and quotas

**Contact Management**
- Advanced filtering and search
- Bulk import/export (CSV, TSV, Excel)
- Automatic duplicate detection
- Data quality scoring
- Custom field mapping

**Background Processing**
- Parallel job execution with Sidekiq
- Intelligent retry logic
- Rate limiting and throttling
- Progress monitoring
- Error handling and logging

**Business Lookup Engine**
- Zipcode-based business discovery
- Multi-provider fallback (Google Places, Yelp)
- Automatic contact creation
- Duplicate prevention
- Batch processing support

**AI Assistant**
- Natural language query parsing
- Intelligent filter generation
- Data insights and recommendations
- Contact segmentation
- Quality analysis

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
- **API Connectors**: http://localhost:3000/admin/api_connectors
- **Business Lookup**: http://localhost:3000/admin/business_lookup
- **AI Assistant**: http://localhost:3000/admin/ai_assistant
- **Sidekiq Monitor**: http://localhost:3000/sidekiq (requires admin login)

Default admin credentials (from seed):
- Email: `admin@example.com`
- Password: `password`

**⚠️ Important**: Change the default password immediately after first login!

## 📊 Usage

### Quick Start Guide

#### 1. Configure API Integrations

Navigate to **API Connectors** dashboard to see all available integrations:

**Required:**
- Twilio Lookup v2 (Account SID + Auth Token)

**Optional Enrichment APIs:**
- **Business Intelligence**: Clearbit, NumVerify
- **Email Discovery**: Hunter.io, ZeroBounce
- **Address Data**: Whitepages Pro, TrueCaller
- **🆕 Geocoding**: Google Geocoding API
- **Business Search**: Google Places, Yelp Fusion
- **🆕 AI Features**: OpenAI, Anthropic Claude, Google Gemini
- **🆕 Messaging**: Twilio SMS & Voice
- **🆕 CRM Sync**: Salesforce, HubSpot, Pipedrive
- **Coverage Check**: Verizon (no API key needed)

The API Connectors dashboard shows:
- Configuration status for each API
- Active data packages
- Connection health checks
- Quick toggle switches for features

#### 2. Import Contacts

**Method A: CSV Upload**
1. Navigate to **Contacts**
2. Click **Import Contacts**
3. Upload CSV with phone numbers (column: `raw_phone_number`)

Example CSV format:
```csv
raw_phone_number
+14155551234
+14155555678
+14155559999
```

**Method B: Business Lookup by Zipcode**
1. Navigate to **Business Lookup**
2. Enter one or more zipcodes (e.g., 90210, 10001)
3. System automatically finds businesses and imports as contacts
4. Businesses are auto-enriched with phone + email data

#### 3. Run Bulk Lookup

1. Go to the **Dashboard**
2. Click **Run Lookup** button
3. Processing happens in background via Sidekiq
4. Enable optional enrichments in **Twilio Credentials** settings:
   - Line Type Intelligence
   - Caller Name (CNAM)
   - SMS Pumping Risk
   - Business Enrichment
   - Email Enrichment
   - Address Enrichment

#### 4. Use AI Assistant

Navigate to **AI Assistant** to:

**Natural Language Search:**
```
"Find tech companies in California with 50+ employees"
"Show me mobile numbers with high SMS risk"
"Businesses in healthcare with verified emails"
```

**Ask Questions:**
```
"What industries should I focus on?"
"Analyze my contact data quality"
"Which contacts have the highest engagement potential?"
```

#### 5. Monitor Progress

- **Dashboard**: Total contacts and processing statistics
- **API Connectors**: Per-API usage and health status
- **Sidekiq UI** (`/sidekiq`): Real-time job monitoring
- **Contacts Page**: Filter by status, enrichment level, quality score
- **Duplicates**: View and merge duplicate contacts

#### 6. Export Results

1. Navigate to **Contacts**
2. Use filters or AI search to select contacts
3. Click **Download** and choose format (CSV/TSV/Excel)

Exported data includes:
- Phone validation (line type, carrier, formatted number)
- Business data (name, industry, employee count, revenue)
- Email addresses (discovered + verified)
- Physical addresses (consumer + business)
- Risk scores (SMS pumping, fraud indicators)
- Quality metrics (data completeness score)
- Verizon coverage availability

## ⚙️ Configuration

### API Integration Setup

Configure API integrations via **Admin → API Connectors** or **Twilio Credentials**:

#### Core APIs

**Twilio Lookup v2** (Required)
```
Account SID: ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
Auth Token: your_auth_token
```
Enable data packages:
- Line Type Intelligence
- Caller Name (CNAM)
- SMS Pumping Risk
- SIM Swap Detection
- Reassigned Number

#### Business Intelligence

**Clearbit** (Premium business data)
```
API Key: sk-xxxxxxxxxxxx
Enable: Business Enrichment toggle
```

**NumVerify** (Basic phone intelligence)
```
API Key: your_numverify_key
```

#### Email Discovery

**Hunter.io** (Email finding)
```
API Key: your_hunter_key
Enable: Email Enrichment toggle
```

**ZeroBounce** (Email verification)
```
API Key: your_zerobounce_key
```

#### Address & Coverage

**Whitepages Pro** (Consumer addresses)
```
API Key: your_whitepages_key
Enable: Address Enrichment toggle
```

**TrueCaller** (Alternative address source)
```
API Key: your_truecaller_key
```

**Verizon Coverage** (5G/LTE availability)
```
No API key needed
Enable: Verizon Coverage Check toggle
```

#### Business Directory

**Google Places** (Business search by zipcode)
```
API Key: AIzaxxxxxxxxxxxxxxxxxxxxxxx
Enable: Zipcode Business Lookup toggle
Results per zipcode: 20 (configurable)
```

**Yelp Fusion** (Alternative business directory)
```
API Key: your_yelp_api_key
```

#### AI Features

**OpenAI** (Natural language search & insights)
```
API Key: sk-xxxxxxxxxxxx
Model: gpt-4o-mini (default) or gpt-4
Enable: AI Features toggle
```

**🆕 Anthropic Claude** (Advanced reasoning & long context)
```
API Key: sk-ant-xxxxxxxxxxxx
Model: claude-3-5-sonnet-20241022 (default)
Enable: Anthropic toggle
Preferred LLM Provider: anthropic
```

**🆕 Google Gemini** (Cost-effective multimodal AI)
```
API Key: AIzaxxxxxxxxxxxxxxxxxxxxxxx
Model: gemini-1.5-flash (default)
Enable: Google AI toggle
Preferred LLM Provider: google
```

**🆕 Google Geocoding** (Address to coordinates)
```
API Key: AIzaxxxxxxxxxxxxxxxxxxxxxxx
Enable: Geocoding toggle
```

### CRM Integrations

**🆕 Salesforce** (Sales CRM sync)
```
Client ID: 3MVGxxxxxxxxxxxxx
Client Secret: your_client_secret
Access Token: (obtained via OAuth)
Refresh Token: (obtained via OAuth)
Instance URL: https://yourcompany.salesforce.com
Enable: Salesforce Sync toggle
Auto Sync: true/false
Sync Direction: bidirectional/push/pull
```

**🆕 HubSpot** (Marketing automation)
```
API Key: pat-na1-xxxxxxxxxxxx
Portal ID: 12345678
Enable: HubSpot Sync toggle
Auto Sync: true/false
```

**🆕 Pipedrive** (Sales pipeline)
```
API Key: your_pipedrive_api_key
Company Domain: yourcompany
Enable: Pipedrive Sync toggle
Auto Sync: true/false
```

### Messaging

**🆕 Twilio SMS** (Outbound messaging)
```
Phone Number: +15551234567
Messaging Service SID: MGxxxxxxxxxx (optional)
Enable: SMS Messaging toggle
Max SMS per Hour: 100
Templates: Intro, Follow-up
```

**🆕 Twilio Voice** (Outbound calls)
```
Voice Webhook URL: https://yourdomain.com/twiml/voice
Recording Enabled: true/false
Enable: Voice Messaging toggle
Max Calls per Hour: 50
```

### Webhooks

**🆕 Webhook Endpoints**
```
SMS Status: https://yourdomain.com/webhooks/twilio/sms_status
Voice Status: https://yourdomain.com/webhooks/twilio/voice_status
Trust Hub: https://yourdomain.com/webhooks/twilio/trust_hub
```
Configure these URLs in your Twilio Console for real-time status updates.

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
- **Phone Lookup**: ~4,000 contacts/hour
- **Business Enrichment**: ~2,000 contacts/hour (additional API calls)
- **Email Discovery**: ~1,500 contacts/hour (rate-limited APIs)
- **Zipcode Lookup**: ~20 businesses per zipcode per request

### Retry Configuration

Jobs automatically retry on transient failures:
- **Max retries**: 3 attempts
- **Backoff**: Exponential (15s, 17s, 19s)
- **Permanent failures**: No retry (invalid numbers, auth errors)

### Feature Toggles

Control which enrichments run via **Twilio Credentials** settings:

**Core Features:**
- `enable_line_type_intelligence`: Phone type detection
- `enable_caller_name`: CNAM lookup
- `enable_sms_pumping_risk`: Fraud risk scoring
- `enable_sim_swap`: SIM swap detection
- `enable_reassigned_number`: Reassigned number detection

**Enrichment Features:**
- `enable_business_enrichment`: Company data enrichment
- `enable_email_enrichment`: Email discovery
- `enable_address_enrichment`: Address lookup
- `enable_duplicate_detection`: Auto-detect duplicates
- `enable_zipcode_lookup`: Business directory search
- `enable_verizon_coverage_check`: Verizon availability
- `enable_trust_hub`: Trust Hub business verification

**🆕 New Features:**
- `enable_geocoding`: Google Geocoding API
- `enable_sms_messaging`: Twilio SMS outreach
- `enable_voice_messaging`: Twilio voice calls
- `enable_ai_features`: OpenAI integration
- `enable_anthropic`: Anthropic Claude integration
- `enable_google_ai`: Google Gemini integration
- `enable_salesforce_sync`: Salesforce CRM sync
- `enable_hubspot_sync`: HubSpot CRM sync
- `enable_pipedrive_sync`: Pipedrive CRM sync

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

## 📝 Available Data Fields

### Phone Validation Fields
| Field | Description | Example |
|-------|-------------|---------|
| `raw_phone_number` | Original input | `4155551234` |
| `formatted_phone_number` | E.164 format | `+14155551234` |
| `carrier_name` | Carrier/provider name | `Verizon Wireless` |
| `line_type` | Phone type | `mobile`, `landline`, `voip` |
| `mobile_country_code` | MCC code | `310` |
| `mobile_network_code` | MNC code | `456` |
| `caller_name` | CNAM lookup result | `John Doe` |
| `sms_pumping_risk_level` | Fraud risk score | `low`, `medium`, `high` |

### Business Intelligence Fields
| Field | Description | Example |
|-------|-------------|---------|
| `business_name` | Company name | `Acme Corporation` |
| `business_industry` | Industry category | `Technology` |
| `business_type` | Company type | `B2B`, `B2C`, `Enterprise` |
| `business_description` | Company description | `Leading SaaS provider...` |
| `business_employee_range` | Employee count | `50-200`, `200-500`, `500+` |
| `business_revenue_range` | Annual revenue | `$1M-$10M`, `$10M-$50M` |
| `business_tags` | Technology stack | `['Ruby', 'Rails', 'AWS']` |
| `is_business` | Business vs consumer | `true`, `false` |

### Email Fields
| Field | Description | Example |
|-------|-------------|---------|
| `email` | Email address | `contact@acme.com` |
| `email_verified` | Verification status | `true`, `false` |
| `email_deliverability` | Deliverability score | `high`, `medium`, `low` |
| `email_source` | Discovery source | `hunter`, `clearbit` |

### Address Fields
| Field | Description | Example |
|-------|-------------|---------|
| `business_address` | Full address | `123 Main St` |
| `business_city` | City | `San Francisco` |
| `business_state` | State/Province | `CA` |
| `business_postal_code` | Zipcode | `94102` |
| `business_country` | Country | `United States` |
| `latitude` | Geo coordinate | `37.7749` |
| `longitude` | Geo coordinate | `-122.4194` |

### Coverage & Risk Fields
| Field | Description | Example |
|-------|-------------|---------|
| `verizon_5g_home_available` | 5G availability | `true`, `false` |
| `verizon_lte_home_available` | LTE availability | `true`, `false` |
| `verizon_fios_available` | Fios availability | `true`, `false` |
| `data_quality_score` | Overall quality (0-100) | `85` |
| `status` | Processing status | `pending`, `completed`, `failed` |
| `error_code` | Error message if failed | `Invalid number format` |

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

## 🎯 Use Cases

### Sales & Marketing
- **Lead Enrichment**: Automatically enhance contact lists with business intelligence
- **List Cleaning**: Validate phone numbers and remove invalid contacts
- **Territory Mapping**: Find all businesses in specific zipcodes or regions
- **Email Discovery**: Build email lists from phone-only contact databases
- **Market Research**: Analyze business distribution by industry and location

### Fraud Prevention
- **SMS Pumping Detection**: Identify high-risk numbers before sending
- **SIM Swap Monitoring**: Detect potential account takeover attempts
- **Number Validation**: Verify phone numbers are active and legitimate
- **Risk Scoring**: Automated fraud risk assessment for all contacts

### Customer Intelligence
- **Consumer vs Business**: Automatically classify contacts
- **Service Availability**: Check Verizon coverage for target addresses
- **Duplicate Management**: Identify and merge duplicate records
- **Data Quality Tracking**: Monitor enrichment completeness

### Research & Analytics
- **Natural Language Queries**: Ask questions about your contact database
- **Industry Analysis**: Understand market composition and trends
- **Quality Metrics**: Track data completeness and accuracy
- **AI-Powered Insights**: Get recommendations from your data

## 📚 Additional Resources

### Platform Documentation
- [Twilio Lookup API v2](https://www.twilio.com/docs/lookup/v2-api)
- [Twilio Trust Hub](https://www.twilio.com/docs/trust-hub)
- [Sidekiq Documentation](https://github.com/sidekiq/sidekiq/wiki)
- [ActiveAdmin Documentation](https://activeadmin.info/documentation.html)
- [Rails Guides](https://guides.rubyonrails.org/)

### API Provider Documentation
- [Clearbit Enrichment API](https://clearbit.com/docs)
- [Hunter.io Email Finder](https://hunter.io/api-documentation)
- [ZeroBounce Email Verification](https://www.zerobounce.net/docs/)
- [Google Places API](https://developers.google.com/maps/documentation/places/web-service)
- [🆕 Google Geocoding API](https://developers.google.com/maps/documentation/geocoding)
- [Yelp Fusion API](https://www.yelp.com/developers/documentation/v3)
- [Whitepages Pro API](https://pro.whitepages.com/developer/documentation/)
- [OpenAI API](https://platform.openai.com/docs)
- [🆕 Anthropic API](https://docs.anthropic.com)
- [🆕 Google AI (Gemini)](https://ai.google.dev/docs)
- [🆕 Salesforce API](https://developer.salesforce.com/docs)
- [🆕 HubSpot API](https://developers.hubspot.com)
- [🆕 Pipedrive API](https://developers.pipedrive.com)

### Getting API Keys
- [Twilio Console](https://console.twilio.com/) - Get Account SID and Auth Token
- [Clearbit](https://clearbit.com/) - Premium business data
- [Hunter.io](https://hunter.io/) - 50 free searches/month
- [ZeroBounce](https://www.zerobounce.net/) - 100 free verifications
- [Google Cloud Console](https://console.cloud.google.com/) - Enable Places & Geocoding API
- [Yelp Developers](https://www.yelp.com/developers) - Free API access
- [OpenAI Platform](https://platform.openai.com/) - Pay-as-you-go pricing
- [🆕 Anthropic Console](https://console.anthropic.com/) - Claude API access
- [🆕 Google AI Studio](https://aistudio.google.com/app/apikey) - Gemini API key
- [🆕 Salesforce Connected App](https://help.salesforce.com/s/articleView?id=sf.connected_app_create.htm) - OAuth setup
- [🆕 HubSpot Private Apps](https://developers.hubspot.com/docs/api/private-apps) - API token
- [🆕 Pipedrive Settings](https://pipedrive.readme.io/docs/how-to-find-the-api-token) - API token

**📖 Complete API Configuration Guide**: See [API_CONFIGURATION_GUIDE.md](API_CONFIGURATION_GUIDE.md) for detailed setup instructions, pricing, and usage examples for all 14+ providers.

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