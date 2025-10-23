# Complete API Configuration Guide
## Twilio Bulk Lookup Platform - Enterprise Contact Intelligence

---

## Table of Contents

1. [Core APIs](#1-core-apis)
2. [Business Intelligence APIs](#2-business-intelligence-apis)
3. [Email Enrichment APIs](#3-email-enrichment-apis)
4. [Address & Geocoding APIs](#4-address--geocoding-apis)
5. [Coverage Check APIs](#5-coverage-check-apis)
6. [Business Directory APIs](#6-business-directory-apis)
7. [AI & LLM APIs](#7-ai--llm-apis)
8. [Business Verification APIs](#8-business-verification-apis)
9. [Webhook Configuration](#9-webhook-configuration)
10. [Cost Tracking](#10-cost-tracking)
11. [Configuration Best Practices](#11-configuration-best-practices)

---

## 1. Core APIs

### Twilio Lookup v2 API (REQUIRED)

**Purpose**: Phone number validation, carrier identification, and fraud detection

**Configuration**:
```ruby
# Required fields
account_sid: "ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
auth_token: "your_auth_token_32_chars"

# Optional data packages (each adds cost per lookup)
enable_line_type_intelligence: true  # +$0.005 per lookup
enable_caller_name: true             # +$0.005 per lookup
enable_sms_pumping_risk: true        # +$0.005 per lookup
enable_sim_swap: true                # +$0.005 per lookup
enable_reassigned_number: true       # +$0.005 per lookup
```

**How to Get API Keys**:
1. Sign up at https://www.twilio.com/try-twilio
2. Navigate to Console → Account → API Keys & Tokens
3. Copy your Account SID and Auth Token
4. Enable Lookup v2 in Console → Develop → Phone Numbers → Lookup

**Pricing**:
- Base lookup: $0.005
- Each data package: +$0.005
- Total with all packages: $0.03/lookup

**Data Returned**:
- `formatted_phone_number` (E.164 format)
- `carrier_name`, `line_type`
- `caller_name` (if enabled)
- `sms_pumping_risk_level`, `sms_pumping_risk_score`
- `valid` (boolean)

---

## 2. Business Intelligence APIs

### 2.1 Clearbit Enrichment API (PREMIUM)

**Purpose**: Comprehensive business data enrichment

**Configuration**:
```ruby
clearbit_api_key: "sk_xxxxxxxxxxxxxxxxxxxxxxxx"
enable_business_enrichment: true
```

**How to Get API Key**:
1. Sign up at https://clearbit.com
2. Navigate to API → API Keys
3. Copy your Secret Key

**Pricing**: ~$0.10 per enrichment

**Data Returned**:
- Company details (name, industry, employee count, revenue)
- Technology stack
- Social media profiles
- Business address and contact info
- Confidence scoring

**Rate Limits**: 600 requests/minute

---

### 2.2 NumVerify API (FALLBACK)

**Purpose**: Basic phone validation and business detection

**Configuration**:
```ruby
numverify_api_key: "your_numverify_api_key"
```

**How to Get API Key**:
1. Sign up at https://numverify.com
2. Navigate to Dashboard → API Access Key
3. Free tier: 250 requests/month

**Pricing**:
- Free: 250/month
- Basic: $9.99/month (5,000 requests)

---

## 3. Email Enrichment APIs

### 3.1 Hunter.io (EMAIL DISCOVERY)

**Purpose**: Find and verify email addresses

**Configuration**:
```ruby
hunter_api_key: "your_hunter_api_key"
enable_email_enrichment: true
```

**How to Get API Key**:
1. Sign up at https://hunter.io
2. Navigate to API → API Keys
3. Free tier: 25 searches/month

**Pricing**:
- Free: 25/month
- Starter: $49/month (500 requests)
- Growth: $99/month (2,500 requests)

**APIs Used**:
- Phone Search: $0.05/search
- Email Finder: $0.05/search
- Email Verifier: $0.01/verification

**Data Returned**:
- `email`, `email_score`, `email_verified`
- `first_name`, `last_name`, `position`
- `linkedin_url`, `twitter_url`

---

### 3.2 ZeroBounce (EMAIL VERIFICATION)

**Purpose**: High-accuracy email validation

**Configuration**:
```ruby
zerobounce_api_key: "your_zerobounce_api_key"
```

**How to Get API Key**:
1. Sign up at https://www.zerobounce.net
2. Navigate to Account → API
3. Free tier: 100 validations

**Pricing**: $0.008 per verification

**Data Returned**:
- `email_verified` (boolean)
- `email_status` (valid, catch-all, invalid, etc.)
- `email_score` (0-100)

---

## 4. Address & Geocoding APIs

### 4.1 Whitepages Pro (ADDRESS LOOKUP)

**Purpose**: Consumer address lookup from phone numbers

**Configuration**:
```ruby
whitepages_api_key: "your_whitepages_api_key"
enable_address_enrichment: true
```

**How to Get API Key**:
1. Sign up at https://pro.whitepages.com
2. Navigate to API Console
3. Request trial or purchase credits

**Pricing**: ~$0.05 per lookup

**Data Returned**:
- `consumer_address`, `consumer_city`, `consumer_state`
- `address_type` (residential, business)
- `address_verified`, `address_confidence_score`

---

### 4.2 Google Geocoding API (NEW!)

**Purpose**: Convert addresses to coordinates (lat/lng)

**Configuration**:
```ruby
google_geocoding_api_key: "AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
enable_geocoding: true
```

**How to Get API Key**:
1. Go to https://console.cloud.google.com
2. Create a new project or select existing
3. Enable "Geocoding API"
4. Navigate to Credentials → Create Credentials → API Key
5. Restrict key to Geocoding API only

**Pricing**: $0.005 per request (first 40,000/month free)

**Data Returned**:
- `latitude`, `longitude`
- `geocoding_accuracy` (rooftop, range_interpolated, etc.)
- `geocoded_at`

**Usage**:
```ruby
# Automatic geocoding when address is enriched
service = GeocodingService.new(contact)
result = service.geocode!

# Batch geocoding
GeocodingService.batch_geocode!(limit: 100)
```

---

### 4.3 TrueCaller API (ALTERNATIVE)

**Purpose**: Alternative address and identity data

**Configuration**:
```ruby
truecaller_api_key: "your_truecaller_api_key"
```

**Note**: Requires business agreement

---

## 5. Coverage Check APIs

### 5.1 Verizon Coverage API

**Purpose**: Check 5G/LTE home internet availability

**Configuration**:
```ruby
enable_verizon_coverage_check: true
# No API key required - uses public endpoints
```

**Data Returned**:
- `verizon_5g_home_available`, `verizon_lte_home_available`, `verizon_fios_available`
- `estimated_download_speed`, `estimated_upload_speed`

**Note**: Requires geocoded coordinates for best results

---

## 6. Business Directory APIs

### 6.1 Google Places API

**Purpose**: Find businesses by zipcode

**Configuration**:
```ruby
google_places_api_key: "AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
enable_zipcode_lookup: true
results_per_zipcode: 20
```

**How to Get API Key**:
1. Go to https://console.cloud.google.com
2. Enable "Places API"
3. Create API key

**Pricing**: $0.017 per search + $0.017 per details request

---

### 6.2 Yelp Fusion API

**Purpose**: Alternative business directory

**Configuration**:
```ruby
yelp_api_key: "your_yelp_api_key"
```

**How to Get API Key**:
1. Sign up at https://www.yelp.com/developers
2. Create an app
3. Free tier: 5,000 calls/day

---

## 7. AI & LLM APIs

### 7.1 OpenAI (GPT Models)

**Purpose**: Natural language processing, sales intelligence

**Configuration**:
```ruby
openai_api_key: "sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
enable_ai_features: true
ai_model: "gpt-4o-mini"  # or "gpt-4"
ai_max_tokens: 500
preferred_llm_provider: "openai"
```

**How to Get API Key**:
1. Sign up at https://platform.openai.com
2. Navigate to API Keys
3. Create new secret key

**Pricing**:
- GPT-4o-mini: $0.150/$0.600 per 1M tokens (input/output)
- GPT-4: $30/$60 per 1M tokens

---

### 7.2 Anthropic Claude (NEW!)

**Purpose**: Advanced reasoning, longer context

**Configuration**:
```ruby
anthropic_api_key: "sk-ant-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
enable_anthropic: true
anthropic_model: "claude-3-5-sonnet-20241022"
preferred_llm_provider: "anthropic"
```

**How to Get API Key**:
1. Sign up at https://console.anthropic.com
2. Navigate to API Keys
3. Create new key

**Pricing**:
- Claude 3.5 Sonnet: $3/$15 per 1M tokens (input/output)
- Claude 3 Haiku: $0.25/$1.25 per 1M tokens

**Usage**:
```ruby
llm = MultiLlmService.new
result = llm.generate("Your prompt here", provider: 'anthropic')
```

---

### 7.3 Google Gemini (NEW!)

**Purpose**: Cost-effective AI with multimodal capabilities

**Configuration**:
```ruby
google_ai_api_key: "AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
enable_google_ai: true
google_ai_model: "gemini-1.5-flash"
preferred_llm_provider: "google"
```

**How to Get API Key**:
1. Go to https://aistudio.google.com/app/apikey
2. Create API key

**Pricing**:
- Gemini 1.5 Flash: $0.075/$0.30 per 1M tokens
- Gemini 1.5 Pro: $1.25/$5 per 1M tokens

---

### 7.4 OpenRouter (NEW! - RECOMMENDED)

**Purpose**: Unified access to 100+ AI models through single API

**Why OpenRouter?**
- ✅ Single API key for 100+ models (GPT, Claude, Gemini, Llama, Mistral, etc.)
- ✅ Automatic fallback if primary model is down
- ✅ Compare models easily without managing multiple integrations
- ✅ Pay-as-you-go with competitive pricing
- ✅ Access to FREE models (Llama 3.1)
- ✅ No provider lock-in

**Configuration**:
```ruby
openrouter_api_key: "sk-or-v1-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
enable_openrouter: true
openrouter_model: "google/gemini-flash-1.5"  # or any model from 100+ options
preferred_llm_provider: "openrouter"

# Optional - For OpenRouter rankings
openrouter_site_url: "https://yourdomain.com"
openrouter_site_name: "Your App Name"
```

**How to Get API Key**:
1. Go to https://openrouter.ai
2. Sign up or log in
3. Navigate to **Keys** → **Create Key**
4. Copy API key (starts with `sk-or-v1-`)
5. Free tier includes $1 in credits

**Recommended Models**:
```ruby
# Best for most queries (fast + cheap)
openrouter_model: "google/gemini-flash-1.5"
# Cost: $0.075/$0.30 per 1M tokens

# Completely FREE (rate-limited)
openrouter_model: "meta-llama/llama-3.1-8b-instruct:free"
# Cost: $0 (20 requests/minute)

# Balanced performance
openrouter_model: "openai/gpt-4o-mini"
# Cost: $0.15/$0.60 per 1M tokens

# High quality analysis
openrouter_model: "anthropic/claude-3.5-sonnet"
# Cost: $3/$15 per 1M tokens
```

**Pricing Examples** (per 1,000 queries):
- FREE Llama model: **$0**
- Gemini Flash: **~$0.02**
- GPT-4o Mini: **~$0.04**
- Claude 3.5: **~$0.90**

**Usage**:
```ruby
# Use OpenRouter
llm = MultiLlmService.new
result = llm.generate("Your prompt", provider: 'openrouter')

# With specific model
result = llm.generate(
  "Your prompt",
  provider: 'openrouter',
  model: 'google/gemini-flash-1.5'
)

# With automatic fallbacks
result = llm.generate(
  "Your prompt",
  provider: 'openrouter',
  route: 'fallback'  # Auto-try alternatives if model fails
)
```

**Available Models**: See full list at https://openrouter.ai/models

**Rate Limits**:
- FREE models: 20 requests/minute
- Paid models: Varies by model (typically 500-1000/minute)

**📖 Complete Guide**: See `OPENROUTER_GUIDE.md` for detailed setup, model comparison, and best practices.

---

## 8. Business Verification APIs

### 8.1 Twilio Trust Hub

**Purpose**: Business verification for compliance

**Configuration**:
```ruby
enable_trust_hub: true
trust_hub_policy_sid: "RNxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"  # optional
trust_hub_webhook_url: "https://yourdomain.com/webhooks/twilio/trust_hub"
auto_create_trust_hub_profiles: false
trust_hub_reverification_days: 90
```

**Webhook URL** (NEW!): `https://yourdomain.com/webhooks/twilio/trust_hub`

**Real-time Status Updates**: Webhooks automatically update contact records when verification status changes

---

## 9. Webhook Configuration

### 9.1 Trust Hub Webhook Endpoint

**Trust Hub Status Updates**:
```
POST https://yourdomain.com/webhooks/twilio/trust_hub
```

### 9.2 Configuring Webhook in Twilio

1. Go to Twilio Console
2. Navigate to Trust Hub Policy settings
3. Configure webhook URL for status updates

### 9.3 Webhook Security

All webhooks are validated using Twilio's signature verification:
```ruby
# Automatically validated in WebhooksController
validator = Twilio::Security::RequestValidator.new(auth_token)
validator.validate(url, request.POST, signature)
```

---

## 10. Cost Tracking

### 10.1 Automatic Cost Logging

All API calls are automatically logged with cost information:

```ruby
# View API usage
ApiUsageLog.today
ApiUsageLog.this_month
ApiUsageLog.by_provider('twilio')

# Cost analysis
ApiUsageLog.total_cost(start_date: 1.month.ago)
ApiUsageLog.total_cost_by_provider(start_date: 1.week.ago)

# Usage statistics
ApiUsageLog.usage_stats(start_date: 1.month.ago)
```

### 10.2 Cost Matrix (Per Request)

| Provider | Service | Cost (USD) |
|----------|---------|-----------|
| Twilio | Basic Lookup | $0.005 |
| Twilio | + Line Type | +$0.005 |
| Twilio | + CNAM | +$0.005 |
| Twilio | + SMS Pumping | +$0.005 |
| Twilio | SMS Send | $0.0079 |
| Twilio | Voice Call | $0.014/min |
| Clearbit | Enrichment | $0.10 |
| Hunter | Email Search | $0.05 |
| Hunter | Email Verify | $0.01 |
| ZeroBounce | Email Verify | $0.008 |
| Google Places | Search | $0.017 |
| Google Places | Details | $0.017 |
| Google Geocoding | Geocode | $0.005 |
| Whitepages | Phone Lookup | $0.05 |
| OpenAI | GPT-4o-mini | $0.0015/1K tokens |
| OpenAI | GPT-4 | $0.03/1K tokens |
| Anthropic | Claude 3.5 Sonnet | $0.003/1K tokens |
| Google AI | Gemini Flash | $0.000075/1K tokens |

### 10.3 Viewing Cost Analytics

Access the API Usage Logs dashboard in ActiveAdmin to view:
- Total costs by provider
- Request success/failure rates
- Average response times
- Cost trends over time

---

## 11. Configuration Best Practices

### 11.1 Recommended Startup Configuration

**Minimum (Free Tier)**:
```ruby
# Twilio only
account_sid: "AC..."
auth_token: "..."
enable_line_type_intelligence: true
```

**Basic ($100/month budget)**:
```ruby
# Twilio + Email
account_sid: "AC..."
auth_token: "..."
enable_line_type_intelligence: true
enable_sms_pumping_risk: true
hunter_api_key: "..."
enable_email_enrichment: true
```

**Professional ($500/month budget)**:
```ruby
# Full enrichment + AI
# Twilio
enable_line_type_intelligence: true
enable_caller_name: true
enable_sms_pumping_risk: true

# Business enrichment
clearbit_api_key: "..."
enable_business_enrichment: true

# Email
hunter_api_key: "..."
zerobounce_api_key: "..."
enable_email_enrichment: true

# AI
openai_api_key: "..."
enable_ai_features: true
ai_model: "gpt-4o-mini"
```

**Enterprise (Unlimited)**:
```ruby
# All features enabled
# + CRM sync
# + Messaging
# + Multi-LLM
# + Geocoding
# + Business directory lookups
```

### 11.2 Rate Limiting Best Practices

- Start with Sidekiq concurrency: 5
- Monitor API usage logs for rate limit errors
- Increase concurrency gradually
- Use batch operations during off-peak hours
- Enable auto-retry with exponential backoff

### 11.3 Security Recommendations

1. **API Key Storage**: Never commit API keys to version control
2. **Environment Variables**: Use Rails credentials or environment variables
3. **Webhook Security**: Always validate Twilio signatures
4. **API Token Rotation**: Rotate API keys and tokens regularly
5. **Database Backups**: Regular backups of API usage logs

### 11.4 Cost Optimization

1. **Selective Enrichment**: Only enrich high-value contacts
2. **Caching**: Check if data already exists before API call
3. **Fallback Providers**: Use cheaper alternatives when possible
4. **Batch Operations**: Process in batches to reduce overhead
5. **Quality Thresholds**: Only process valid numbers

---

## Quick Reference: Environment Variables

```bash
# .env file (example)
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=your_auth_token
CLEARBIT_API_KEY=sk_xxxxxxxxxxxx
HUNTER_API_KEY=your_hunter_key
ZEROBOUNCE_API_KEY=your_zerobounce_key
GOOGLE_PLACES_API_KEY=AIzaSyXXXXXXXX
GOOGLE_GEOCODING_API_KEY=AIzaSyXXXXXXXX
OPENAI_API_KEY=sk-xxxxxxxxxxxx
ANTHROPIC_API_KEY=sk-ant-xxxxxxxxxxxx
GOOGLE_AI_API_KEY=AIzaSyXXXXXXXX
HUBSPOT_API_KEY=pat-na1-xxxxxxxxxxxx
SALESFORCE_CLIENT_ID=3MVGxxxxxxxxxxxx
SALESFORCE_CLIENT_SECRET=xxxxxxxxxxxx
PIPEDRIVE_API_KEY=xxxxxxxxxxxx
```

---

## Support & Documentation

- **Twilio Docs**: https://www.twilio.com/docs/lookup
- **OpenAI Docs**: https://platform.openai.com/docs
- **Anthropic Docs**: https://docs.anthropic.com
- **Google AI Docs**: https://ai.google.dev
- **Clearbit Docs**: https://clearbit.com/docs
- **Hunter Docs**: https://hunter.io/api-documentation
- **HubSpot Docs**: https://developers.hubspot.com
- **Salesforce Docs**: https://developer.salesforce.com
- **Pipedrive Docs**: https://developers.pipedrive.com

---

**Last Updated**: October 2025
**Version**: 2.0.0
