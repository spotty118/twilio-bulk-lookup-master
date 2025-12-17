# Project Structure

## Directory Layout

```
app/
├── admin/              # ActiveAdmin resource definitions
├── controllers/
│   ├── api/v1/         # REST API endpoints (contacts)
│   ├── concerns/       # Controller concerns
│   └── *.rb            # Main controllers (health, lookup, webhooks)
├── jobs/               # Sidekiq background jobs
│   ├── lookup_request_job.rb      # Core Twilio lookup
│   ├── enrichment_coordinator_job.rb  # Orchestrates enrichment
│   └── *_enrichment_job.rb        # Individual enrichment jobs
├── middleware/         # Rack middleware (request logging)
├── models/
│   ├── concerns/
│   │   └── contact/    # Domain-specific contact concerns
│   └── *.rb            # ActiveRecord models
├── services/           # Business logic services
│   ├── crm_sync/       # CRM integration services
│   └── *.rb            # Enrichment, lookup, AI services
└── views/              # ERB templates (minimal, mostly admin)

config/
├── initializers/       # Rails initializers (ActiveAdmin, Devise, etc.)
├── environments/       # Environment-specific config
├── routes.rb           # Route definitions
└── sidekiq.yml         # Sidekiq configuration

db/
├── migrate/            # Database migrations
├── schema.rb           # Current schema
└── seeds.rb            # Seed data (default admin user)

spec/                   # RSpec tests
├── factories/          # FactoryBot factories
├── models/             # Model specs
├── services/           # Service specs
├── jobs/               # Job specs
└── integration/        # Integration tests
```

## Key Patterns

### Models
- `Contact` is the central model with domain concerns extracted to `app/models/concerns/contact/`
- Concerns: `BusinessIntelligence`, `PhoneIntelligence`, `EnrichmentTracking`, `VerizonCoverage`, `TrustHubVerification`, `DuplicateDetection`
- `TwilioCredential` stores API keys and feature toggles

### Services
- Services follow `ServiceName.method(args)` pattern with class method entry points
- External API calls wrapped with `CircuitBreakerService.call(:provider_name)`
- Multi-provider fallback pattern (try provider A, then B, then C)

### Jobs
- Jobs receive IDs, not objects (Sidekiq best practice)
- `LookupRequestJob` handles core Twilio lookup with retry logic
- `EnrichmentCoordinatorJob` fans out to individual enrichment jobs
- Retry configuration uses exponential backoff with jitter

### API
- REST API at `/api/v1/` with Bearer token authentication
- Webhooks at `/webhooks/twilio/*` for status callbacks

### Admin
- All admin pages defined in `app/admin/`
- Dashboard at `/admin` (root redirects here)
- Sidekiq UI at `/sidekiq` (requires admin auth)

## Configuration Priority
1. Environment variables
2. Rails encrypted credentials
3. Database (TwilioCredential model)
