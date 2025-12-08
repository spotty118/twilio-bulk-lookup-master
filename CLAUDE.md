# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## PRIME DIRECTIVE

**Every task in this repository MUST execute the Darwin-Gödel Machine framework.**

No exceptions. No shortcuts. Depth scales with complexity, but all 8 phases execute.

- Simple one-liner fix: 3 solutions, 2 generations, 5 minutes
- Complex architecture task: 7 solutions, 7 generations, full formalism
- **Mandatory**: Fitness scoring, assumption tracking, self-reflection, meta-improvement

**Compliance Mode**: STRICT
**Deviation Tolerance**: ZERO
**Framework Status**: ACTIVE UNIVERSALLY

---

# Darwin-Gödel Machine

A cognitive architecture that evolves populations of solutions while formally verifying improvements before self-modification.

## Core Philosophy

**Darwin**: Generate diverse solution populations → Apply selection pressure → Evolve toward optimum
**Gödel**: Verify improvements formally before accepting → Enable recursive self-improvement → Prove modifications beneficial

**Combined**: Explore solution space evolutionarily, but only commit changes with verification proofs.

---

## THE EXECUTION LOOP

Every problem runs this loop. No exceptions. Depth scales with complexity.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  PHASE 1: DECOMPOSE                                                         │
│  ├─ Parse the problem into atomic sub-problems                              │
│  ├─ Identify constraints, success criteria, edge cases                      │
│  ├─ Define fitness function: What makes a solution "better"?                │
│  └─ Estimate complexity class → determines population size & generations    │
├─────────────────────────────────────────────────────────────────────────────┤
│  PHASE 2: GENESIS (Population Initialization)                               │
│  ├─ Generate N diverse initial solutions (N = 3-7 based on complexity)      │
│  ├─ Ensure diversity: different algorithms, paradigms, trade-offs           │
│  ├─ Each solution must be complete and executable (no stubs)                │
│  └─ Tag each with: approach_type, expected_strengths, expected_weaknesses   │
├─────────────────────────────────────────────────────────────────────────────┤
│  PHASE 3: EVALUATE (Fitness Assessment)                                     │
│  ├─ Score each solution against fitness function (1-100)                    │
│  ├─ Test against edge cases and adversarial inputs                          │
│  ├─ Measure: correctness, efficiency, readability, robustness               │
│  └─ Rank population by composite fitness score                              │
├─────────────────────────────────────────────────────────────────────────────┤
│  PHASE 4: EVOLVE (Selection + Mutation + Crossover)                         │
│  ├─ SELECT: Keep top 50% of population                                      │
│  ├─ MUTATE: Apply mutation operators to survivors (see §Mutations)          │
│  ├─ CROSSOVER: Combine strengths of top 2 solutions into hybrid             │
│  └─ Generate new candidates to restore population size                      │
├─────────────────────────────────────────────────────────────────────────────┤
│  PHASE 5: VERIFY (Gödel Proof Gate)                                         │
│  ├─ For each evolved solution, PROVE improvement over parent                │
│  ├─ Proof types: logical deduction, test coverage, complexity analysis      │
│  ├─ REJECT any mutation that cannot be formally justified                   │
│  └─ Only verified improvements pass to next generation                      │
├─────────────────────────────────────────────────────────────────────────────┤
│  PHASE 6: CONVERGE (Termination Check)                                      │
│  ├─ If best solution meets success criteria → DELIVER                       │
│  ├─ If fitness plateau (no improvement in 2 generations) → DELIVER best     │
│  ├─ If generation limit reached → DELIVER best with caveats                 │
│  └─ Else → Return to PHASE 4 with evolved population                        │
├─────────────────────────────────────────────────────────────────────────────┤
│  PHASE 7: REFLECT (Mandatory Self-Reflection)                               │
│  ├─ SOLUTION REFLECTION: Why did winner win? What trait was decisive?       │
│  ├─ PROCESS REFLECTION: Did I explore right space? What did I miss?         │
│  ├─ ASSUMPTION AUDIT: List all assumptions, mark validated/invalidated      │
│  ├─ MUTATION ANALYSIS: Which mutations helped? Which wasted cycles?         │
│  ├─ PROOF QUALITY: Were proofs rigorous or hand-wavy?                       │
│  ├─ FAILURE ANALYSIS: What would have caught mistakes earlier?              │
│  └─ Score reasoning quality 1-10, justify score                             │
├─────────────────────────────────────────────────────────────────────────────┤
│  PHASE 8: META-IMPROVE (Recursive Self-Improvement)                         │
│  ├─ Extract: What lessons apply to future problems?                         │
│  ├─ Propose: Concrete process improvements (not vague)                      │
│  ├─ Verify: Would proposed improvement actually help?                       │
│  ├─ If verified → Add to ACTIVE_LESSONS for this conversation               │
│  └─ Apply ACTIVE_LESSONS at start of next problem in conversation           │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## COMPLEXITY SCALING

| Problem Type | Population Size | Max Generations | Mutation Rate |
|--------------|-----------------|-----------------|---------------|
| Simple (one-liner fix) | 3 | 2 | Low |
| Medium (single function) | 5 | 3 | Medium |
| Complex (module/feature) | 7 | 5 | High |
| Architecture (system design) | 7 | 7 | High + Crossover |

---

## FITNESS FUNCTION TEMPLATE

Define before generating solutions:

```
FITNESS(solution) = weighted_sum(
    CORRECTNESS:   Does it produce correct output for all inputs?      (weight: 0.40)
    ROBUSTNESS:    Does it handle edge cases and failures gracefully?  (weight: 0.25)
    EFFICIENCY:    Time/space complexity relative to optimal?          (weight: 0.15)
    READABILITY:   Can a mid-level dev understand it in 30 seconds?    (weight: 0.10)
    EXTENSIBILITY: How hard to modify for likely future requirements?  (weight: 0.10)
)
```

Adjust weights based on problem priorities. User can override.

---

## MUTATION OPERATORS

Apply during EVOLVE phase to create variants:

### Code Mutations
| Operator | Description | When to Apply |
|----------|-------------|---------------|
| SIMPLIFY | Remove unnecessary complexity | When solution is >20 lines |
| GENERALIZE | Make specific code more abstract | When pattern appears 2+ times |
| SPECIALIZE | Optimize for specific use case | When generality hurts performance |
| EXTRACT | Pull out reusable component | When code can benefit others |
| INLINE | Remove unnecessary abstraction | When abstraction adds no value |
| PARALLELIZE | Add concurrency | When independent operations exist |
| MEMOIZE | Cache repeated computations | When same inputs recur |
| GUARD | Add defensive checks | When edge cases discovered |

### Architecture Mutations
| Operator | Description | When to Apply |
|----------|-------------|---------------|
| SPLIT | Decompose into smaller units | When module does too much |
| MERGE | Combine related components | When separation adds overhead |
| LAYER | Add abstraction layer | When coupling is too tight |
| FLATTEN | Remove unnecessary layers | When indirection hurts clarity |
| ASYNC | Convert to async processing | When blocking is unnecessary |
| CACHE | Add caching layer | When repeated expensive operations |
| QUEUE | Add message queue | When decoupling needed |
| RETRY | Add retry logic | When transient failures possible |

---

## ASSUMPTION TRACKING

Track assumptions throughout the ENTIRE loop, not just in reflection.

### Assumption Log Format

```
ASSUMPTION LOG:
┌─────┬─────────────────────────────┬─────────┬──────────┬───────────┐
│ ID  │ Assumption                  │ Phase   │ Risk     │ Status    │
├─────┼─────────────────────────────┼─────────┼──────────┼───────────┤
│ A1  │ Input size < 10,000         │ DECOMP  │ Medium   │ UNCHECKED │
│ A2  │ No concurrent modifications │ GENESIS │ High     │ VALIDATED │
│ A3  │ API returns JSON            │ GENESIS │ Low      │ UNCHECKED │
│ A4  │ O(n²) acceptable for N<100  │ EVOLVE  │ Medium   │ VALIDATED │
└─────┴─────────────────────────────┴─────────┴──────────┴───────────┘
```

### Assumption Risk Levels

| Risk | Definition | Action Required |
|------|------------|-----------------|
| **HIGH** | If wrong, solution is fundamentally broken | MUST validate before delivery |
| **MEDIUM** | If wrong, solution degrades but works | SHOULD validate, document if not |
| **LOW** | If wrong, minor impact | Document, validate if easy |

**RULE: HIGH risk + Weak validation = STOP. Get stronger validation or flag uncertainty.**

---

## REFLECTION OUTPUT FORMAT

```
### REFLECTION (Phase 7)

#### Solution Analysis
- Winner: [ID]
- Decisive trait: [what made it win]
- Emerged at: [Genesis / Generation N via mutation X]
- Biggest weakness: [trade-off accepted]

#### Process Analysis
- Approaches NOT tried: [list 2-3 with reasons]
- Highest effort area: [phase/activity] — Justified: [yes/no]
- If starting over: [what would change]

#### Assumption Audit
| Assumption | Risk | Status | Evidence |
|------------|------|--------|----------|
| ... | ... | ... | ... |

Unvalidated HIGH-risk assumptions: [count] ← MUST BE 0

#### Self-Score: [1-10]
Justification: [why this score]
```

---

## QUICK-START HEURISTICS

For rapid application without full formalism:

**When time-constrained:**
1. Generate 3 solutions (diverse approaches)
2. Score each on correctness + robustness only
3. Mutate top 1 solution once
4. Verify mutation improves fitness
5. Deliver best

**When quality is paramount:**
1. Full 7-solution population
2. 5+ generations with crossover
3. All proof types required
4. Meta-improvement phase mandatory

---

## ADVERSARIAL SELF-CHECK

Before delivering final solution, ask:

1. "What input would break this?"
2. "What assumption am I making that might be wrong?"
3. "If I had to attack this code, how would I?"
4. "What would a senior engineer critique?"
5. "Does the simplest version of this work just as well?"

If any answer reveals a flaw → one more evolution cycle.

---

# Twilio Bulk Lookup: Architecture & Development Guide

## System Architecture

**Type**: Rails 7.2 monolith with service-oriented design
**Scale**: 11,000+ LOC, 14 external API integrations
**Stack**: PostgreSQL, Redis/Sidekiq, ActiveAdmin

### High-Level Data Flow

```
CSV Import → Contact (pending)
    ↓
LookupRequestJob → Twilio Lookup API v2
    ↓
Contact.mark_completed! → Enrichment Cascade
    ↓
├─ Business? → BusinessEnrichmentJob → TrustHubEnrichmentJob
│                                    └→ EmailEnrichmentJob
│
└─ Consumer? → AddressEnrichmentJob → VerizonCoverageCheckJob

Background: DuplicateDetectionJob, CrmSyncJob (continuous)
```

### Critical Patterns

**1. Job Chaining via Conditional Callbacks**
Jobs enqueue subsequent jobs based on contact state. Example:
- `LookupRequestJob` (lines 136-144) conditionally enqueues `BusinessEnrichmentJob` or `AddressEnrichmentJob`
- `BusinessEnrichmentJob` (lines 44-52) triggers `TrustHubEnrichmentJob` and `EmailEnrichmentJob`

**2. Singleton Configuration Pattern**
`TwilioCredential.current` caches credentials for 1 hour (lines 20-24). All API keys and feature flags stored here.

**3. Idempotency via State Checks**
Every job checks completion state before processing:
```ruby
return if contact.lookup_completed?  # Skip if already done
return unless contact.status == 'pending' || contact.status == 'failed'
```

**4. Retry Logic with Exponential Backoff**
All jobs use `retry_on` with 2-3 attempts:
```ruby
retry_on Twilio::REST::RestError, wait: :exponentially_longer, attempts: 3
discard_on ActiveRecord::RecordNotFound  # Don't retry permanent failures
```

**5. Service Layer Abstraction**
Business logic lives in `/app/services/`, not models/jobs:
- `BusinessEnrichmentService.enrich(contact)` - Tries Clearbit → NumVerify → OpenCNAM
- `MultiLlmService.generate(prompt)` - Routes to OpenAI/Anthropic/Google based on config
- `DuplicateDetectionService.find_duplicates(contact)` - Fingerprint-based matching

**6. Callback-Driven Model Updates**
`Contact` model uses 6 callbacks for automatic data enrichment:
- `after_save :update_fingerprints_if_needed` (lines 394-410)
- `after_save :calculate_quality_score_if_needed` (lines 401-414)

⚠️ **Performance Warning**: Callbacks can cause N+1 queries on bulk operations.

## Development Commands

### Setup
```bash
# Install dependencies
bundle install

# Database setup
rails db:create db:migrate db:seed

# Start Redis (required for Sidekiq)
redis-server

# Start all services (requires 3 terminals)
rails server              # Terminal 1: Web server (port 3000)
bundle exec sidekiq       # Terminal 2: Background jobs
redis-server              # Terminal 3: Job queue (if not system service)
```

### Testing
⚠️ **CRITICAL**: This codebase currently has **zero test coverage**.

When writing tests (RSpec + FactoryBot installed):
```bash
# Run all tests (once they exist)
bundle exec rspec

# Run single test file
bundle exec rspec spec/models/contact_spec.rb

# Run specific test
bundle exec rspec spec/models/contact_spec.rb:42

# With coverage report
COVERAGE=true bundle exec rspec
```

### Code Quality
```bash
# Lint Ruby code
bundle exec rubocop

# Auto-fix safe issues
bundle exec rubocop -a

# Security audit
bundle exec brakeman

# Rails console
rails console

# Database console
rails dbconsole
```

### Sidekiq Monitoring
```bash
# Web UI (requires admin login)
open http://localhost:3000/sidekiq

# Clear failed jobs
rails runner "Sidekiq::RetrySet.new.clear"

# View queue stats
rails runner "puts Sidekiq::Stats.new.queues.inspect"
```

## Project-Specific Fitness Criteria

When working on this codebase, apply Darwin-Gödel with these domain-specific weights:

### For Sidekiq Jobs
- **Idempotency** (0.30): Can safely retry without duplicate API calls?
- **Rate Limit Handling** (0.25): Exponential backoff configured correctly?
- **Error Classification** (0.25): Distinguishes retryable vs permanent failures?
- **Memory Efficiency** (0.20): Handles large batches without OOM?

### For API Integrations (Services)
- **Graceful Degradation** (0.30): Fallback when primary API unavailable?
- **Credential Security** (0.25): Never log API keys, use encrypted storage?
- **Response Caching** (0.20): Cache where appropriate (e.g., geocoding)?
- **Timeout Handling** (0.15): Network timeouts configured?
- **Cost Tracking** (0.10): Log API usage to `ApiUsageLog`?

### For Rails Models
- **Query Efficiency** (0.35): Avoids N+1 queries? Uses `includes`/`joins`?
- **Validation Completeness** (0.25): Phone format, presence checks?
- **Scope Composability** (0.20): Scopes can be chained safely?
- **Callback Safety** (0.20): Callbacks don't cause performance issues?

## Darwin-Gödel Framework Extensions

**Source**: DARWIN_GODEL_META_IMPROVEMENTS.md (extracted from "fix it all" remediation)
**Status**: ACTIVE - Apply to all future work

### Post-Edit Validation

After Write or Edit on any `.rb` file:
1. Auto-run: `ruby -c {file_path}`
2. If error → fix immediately before continuing
3. Report: "✓ Syntax validated" (silent on success)

**Rationale**: Catches syntax errors while context is fresh in working memory.

### Migration Creation Protocol

When creating migrations WITHOUT Rails CLI:
1. Generate timestamp: `date +%Y%m%d%H%M%S`_`openssl rand -hex 2`
2. Add query pattern comment explaining index purpose
3. Use `unless_exists: true` for all indices
4. Add reversibility check (does `down` method exist?)

**Example**:
```ruby
# Query pattern: Contact.where(phone_fingerprint: x, is_duplicate: true)
# Found in: app/models/contact.rb:145
add_index :contacts, :phone_fingerprint,
  where: "is_duplicate = true AND phone_fingerprint IS NOT NULL",
  unless_exists: true
```

### Test Infrastructure Requirements

All tests tagged `:job`, `:integration`, or `:system` MUST declare dependencies:
```ruby
# INFRASTRUCTURE REQUIRED:
# - PostgreSQL with SERIALIZABLE isolation
# - Redis (for Sidekiq tests)
# - Run with: SIDEKIQ_CONCURRENCY=10 bundle exec rspec
```

### Factory Trait Composition

Enrichment traits auto-include base `:enriched` trait:
```ruby
trait :with_business do
  enriched  # Auto-includes completed status, timestamps
  is_business { true }
  business_enriched { true }
end
```

**Usage**: `create(:contact, :with_business)` → auto-gets completed status

### Index Creation Checklist

Before creating database index:
- [ ] Grep for column usage: `grep -r "column_name" app/`
- [ ] Extract WHERE/ORDER BY patterns from code
- [ ] Document query pattern as migration comment
- [ ] Verify partial index WHERE matches query WHERE exactly
- [ ] Add TODO for post-deployment pg_stat_statements validation

**Warning**: Partial indices only used if query WHERE clause EXACTLY matches index WHERE clause.

## Known Technical Debt

1. **No Test Coverage**: Priority #1 - Add RSpec tests for Contact model and critical jobs
2. **Credential Security**: `TwilioCredential` caches plaintext API keys in memory
3. **Callback Complexity**: Contact model has 6 callbacks that can cause N+1 queries
4. **Broad Exception Handling**: 34 instances of `rescue => e` instead of specific exceptions
5. **Sequential Job Chaining**: Jobs enqueue serially instead of parallel where possible
6. **Missing Database Indices**: No index on `(status, business_enriched)` for common queries

## Critical Files to Understand

**Core Models:**
- `app/models/contact.rb` (492 LOC) - Central entity with 30+ scopes and business logic
- `app/models/twilio_credential.rb` (60 LOC) - Singleton configuration with caching

**Primary Jobs:**
- `app/jobs/lookup_request_job.rb` - Entry point for Twilio API integration
- `app/jobs/business_enrichment_job.rb` - Orchestrates Clearbit/NumVerify enrichment

**Key Services:**
- `app/services/multi_llm_service.rb` - Routes AI requests to OpenAI/Anthropic/Google
- `app/services/business_enrichment_service.rb` - Multi-provider fallback logic
- `app/services/duplicate_detection_service.rb` - Fingerprint-based duplicate detection

**Admin Interface:**
- `app/admin/contacts.rb` - Main contact management UI with CSV import
- `app/admin/api_connectors.rb` - Unified API configuration dashboard
- `app/admin/dashboard.rb` - Real-time stats with Turbo Streams

## Database Schema Patterns

**Status Workflow:**
```
pending → processing → completed
                    ↘ failed
```

**Enrichment Flags:**
- `business_enriched`, `email_enriched`, `address_enriched`, `trust_hub_enriched`
- All boolean flags with corresponding `*_enriched_at` timestamps

**Duplicate Detection:**
- `phone_fingerprint`, `name_fingerprint`, `email_fingerprint` (normalized for matching)
- `duplicate_of_id` (points to primary contact)
- `is_duplicate` (boolean flag)

**Quality Scoring:**
- `data_quality_score` (0-100, calculated from 20 data fields)
- `completeness_percentage` (percent of fields populated)

## External API Dependencies

**Required:**
- Twilio Lookup v2 (Account SID + Auth Token)

**Optional Enrichment:**
- Business: Clearbit, NumVerify
- Email: Hunter.io, ZeroBounce
- Address: Whitepages Pro, TrueCaller
- Geocoding: Google Maps Geocoding API
- Business Search: Google Places, Yelp Fusion
- AI: OpenAI, Anthropic Claude, Google Gemini
- CRM: Salesforce, HubSpot, Pipedrive
- Coverage: Verizon (no API key needed)

All API keys configured in `TwilioCredential` model or environment variables.

## Performance Considerations

**Sidekiq Concurrency:**
- Default: 5 parallel jobs (configured in `config/sidekiq.yml`)
- Production: 10-20 jobs (monitor rate limits)
- With concurrency=5: ~4,000 contacts/hour lookup rate

**Database Indices:**
- Conditional indices on `contacts(status)` WHERE status = 'pending'/'completed'
- Missing indices on `(status, business_enriched)` - add if slow queries detected

**Caching:**
- `TwilioCredential.current` cached 1 hour in Rails.cache
- No HTTP response caching currently implemented

**N+1 Query Risks:**
- Contact callbacks can cause N+1 on bulk updates
- ActiveAdmin index pages use eager loading where needed
