# Laravel Services Conversion - Quick Start Guide

## What's Been Completed

✓ **4 out of 18 services converted** (22%)
✓ **Complete conversion documentation**
✓ **Directory structure created**

### Converted Services (Ready to Use)

1. **CircuitBreakerService.php** - Circuit breaker pattern for API resilience
2. **ErrorTrackingService.php** - Unified error logging and Sentry integration
3. **MessagingService.php** - Twilio SMS/voice messaging
4. **PromptSanitizer.php** - AI prompt injection prevention

All files located in: `/home/user/twilio-bulk-lookup-master/laravel-app/app/Services/`

## Documentation Files Created

- **CONVERSION_STATUS.md** - Detailed conversion status and next steps
- **SERVICES_CONVERSION_SUMMARY.md** - Conversion patterns and best practices
- **QUICK_START.md** (this file) - Quick reference

## Installation Requirements

### Step 1: Install Required Packages
```bash
cd /home/user/twilio-bulk-lookup-master/laravel-app

# Essential packages
composer require twilio/sdk              # Twilio integration ✓
composer require guzzlehttp/guzzle       # HTTP client for APIs

# Recommended packages
composer require spatie/async            # For parallel processing
composer require sentry/sentry-laravel   # Error tracking
```

### Step 2: Configure Environment
Add to `.env`:
```env
# Twilio Configuration
TWILIO_ACCOUNT_SID=your_account_sid
TWILIO_AUTH_TOKEN=your_auth_token
TWILIO_PHONE_NUMBER=your_phone_number

# Redis (for circuit breaker)
REDIS_HOST=127.0.0.1
REDIS_PASSWORD=null
REDIS_PORT=6379

# API Keys (add as needed)
CLEARBIT_API_KEY=
HUNTER_API_KEY=
GOOGLE_PLACES_API_KEY=
OPENAI_API_KEY=
```

## Usage Examples

### Circuit Breaker Service
```php
use App\Services\CircuitBreakerService;

// Protect API calls with circuit breaker
$result = CircuitBreakerService::call('clearbit', function() {
    $client = new \GuzzleHttp\Client();
    return $client->get('https://company.clearbit.com/v1/domains/find');
});

// Check circuit status
$state = CircuitBreakerService::state('clearbit'); // 'closed', 'open', 'half_open'

// Get all circuit states
$allStates = CircuitBreakerService::allStates();

// Manually reset a circuit
CircuitBreakerService::reset('clearbit');
```

### Error Tracking Service
```php
use App\Services\ErrorTrackingService;

// Capture exceptions
try {
    // Your code
} catch (\Exception $e) {
    ErrorTrackingService::capture($e, ['contact_id' => 123], ['api' => 'twilio']);
}

// Log warnings
ErrorTrackingService::warn("Rate limit approaching", ['api' => 'twilio']);

// Track rate limits
ErrorTrackingService::trackRateLimit('twilio', 60, ['contact_id' => 123]);

// Track circuit breaker events
ErrorTrackingService::trackCircuitBreaker('clearbit', 'open');
```

### Messaging Service
```php
use App\Services\MessagingService;
use App\Models\Contact;

$contact = Contact::find(1);
$service = new MessagingService($contact);

// Send SMS
$result = $service->sendSms("Hello from Laravel!");

// Send from template
$result = $service->sendSmsFromTemplate('intro');

// Send AI-generated message
$result = $service->sendAiGeneratedSms('intro');

// Bulk send
$contacts = Contact::where('sms_opt_out', false)->limit(10)->get();
$results = MessagingService::sendBulkSms($contacts, "Hello everyone!");
```

### Prompt Sanitizer
```php
use App\Services\PromptSanitizer;

// Sanitize user input before AI prompts
$safeInput = PromptSanitizer::sanitize($userInput, 500, 'search_query');

// Sanitize contact data
$safeContact = PromptSanitizer::sanitizeContact($contact);

// Sanitize array of data
$safeData = PromptSanitizer::sanitizeHash([
    'name' => $name,
    'query' => $query,
], [
    'name' => ['max_length' => 100],
    'query' => ['max_length' => 500],
]);
```

## Remaining Services to Convert (14)

### Priority 1 - Core Services
- **MultiLlmService.php** - OpenAI, Anthropic, Google AI, OpenRouter

### Priority 2 - Enrichment Services (9)
- BusinessEnrichmentService.php
- EmailEnrichmentService.php
- AddressEnrichmentService.php
- BusinessLookupService.php
- GeocodingService.php
- DuplicateDetectionService.php
- ParallelEnrichmentService.php
- VerizonCoverageService.php
- TrustHubService.php

### Priority 3 - CRM Services (3)
- CrmSync/HubspotService.php
- CrmSync/SalesforceService.php
- CrmSync/PipedriveService.php

### Priority 4 - AI Services (1)
- AiAssistantService.php

## Next Steps for Completion

1. **Review Completed Services**
   - Study the 4 converted services as templates
   - Understand conversion patterns used

2. **Install Dependencies**
   ```bash
   composer install
   composer require guzzlehttp/guzzle spatie/async
   ```

3. **Convert Remaining Services**
   - Use completed services as templates
   - Follow patterns in CONVERSION_STATUS.md
   - Test each service after conversion

4. **Create Tests**
   ```bash
   php artisan make:test Services/CircuitBreakerServiceTest --unit
   php artisan make:test Services/MessagingServiceTest --unit
   ```

5. **Integration Testing**
   - Test with actual Contact model
   - Verify API integrations
   - Test circuit breaker behavior

## Common Conversion Patterns

### Pattern 1: HTTParty → Guzzle
```ruby
# Rails
response = HTTParty.get(url, headers: headers)
data = response.parsed_response
```
```php
// Laravel
$client = new \GuzzleHttp\Client();
$response = $client->get($url, ['headers' => $headers]);
$data = json_decode($response->getBody(), true);
```

### Pattern 2: Circuit Breaker Integration
```ruby
# Rails
result = CircuitBreakerService.call(:api_name) do
  HTTParty.get(url)
end
```
```php
// Laravel
$result = CircuitBreakerService::call('api_name', function() use ($url) {
    return (new Client())->get($url);
});
```

### Pattern 3: Error Handling
```ruby
# Rails
rescue HTTParty::Error => e
  Rails.logger.error "Error: #{e.message}"
end
```
```php
// Laravel
catch (\GuzzleHttp\Exception\GuzzleException $e) {
    Log::error("Error: {$e->getMessage()}");
}
```

## Troubleshooting

### Issue: Redis connection failed
**Solution**: Ensure Redis is running and configured in `.env`
```bash
redis-cli ping  # Should return PONG
```

### Issue: Twilio authentication failed
**Solution**: Verify credentials in `.env`
```bash
TWILIO_ACCOUNT_SID=ACxxxxx
TWILIO_AUTH_TOKEN=your_token
```

### Issue: Class not found
**Solution**: Run composer autoload
```bash
composer dump-autoload
```

## Testing Checklist

- [ ] Circuit breaker opens after threshold failures
- [ ] Circuit breaker closes after successful requests
- [ ] Error tracking logs to correct channels
- [ ] SMS sends successfully with valid credentials
- [ ] Rate limiting prevents excessive API calls
- [ ] Prompt sanitizer blocks injection attempts

## Support

For detailed conversion information, see:
- **CONVERSION_STATUS.md** - Complete status and next steps
- **SERVICES_CONVERSION_SUMMARY.md** - Patterns and dependencies

For Laravel documentation:
- HTTP Client: https://laravel.com/docs/http-client
- Redis: https://laravel.com/docs/redis
- Queue: https://laravel.com/docs/queues

---

**Status**: 4/18 services completed (22%)
**Next**: Convert MultiLlmService or enrichment services
**Estimated Time**: 6-8 hours for remaining services
