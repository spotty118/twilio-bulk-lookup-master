# Requirements Document

## Introduction

This specification defines the requirements for establishing a foundational test suite for the Twilio Bulk Lookup application. The codebase currently has 0% test coverage, creating high risk for regressions when implementing bug fixes and new features. This initiative focuses on critical path coverage for the most important components: job processing, status management, duplicate detection, circuit breakers, and error handling patterns identified in the bug fix reports.

## Glossary

- **Contact**: The central data model representing a phone number and its enriched data (150+ fields)
- **LookupRequestJob**: The Sidekiq background job that performs Twilio Lookup v2 API calls
- **Status Workflow**: The state machine governing contact processing (pending → processing → completed/failed)
- **Fingerprint**: A SHA-256 hash used for duplicate detection based on phone, name, or email
- **Circuit Breaker**: A pattern using the Stoplight gem that prevents cascading failures by stopping requests to failing services
- **Property-Based Test**: A test that verifies properties hold across many randomly generated inputs using the rspec-property gem
- **Pessimistic Locking**: Database-level locking using `with_lock` to prevent race conditions
- **Webhook**: Incoming HTTP callbacks from Twilio for SMS/Voice status updates
- **Enrichment Pipeline**: The cascade of jobs that enrich contact data after initial lookup

## Requirements

### Requirement 1

**User Story:** As a developer, I want comprehensive tests for the Contact model status workflow, so that I can confidently make changes without breaking the state machine.

#### Acceptance Criteria

1. WHEN a contact is created, THE Contact model SHALL set status to 'pending' by default
2. WHEN a contact transitions from 'pending' to 'processing', THE Contact model SHALL allow the transition
3. WHEN a contact transitions from 'processing' to 'completed', THE Contact model SHALL allow the transition
4. WHEN a contact transitions from 'processing' to 'failed', THE Contact model SHALL allow the transition
5. WHEN a contact attempts to transition from 'completed' to 'pending', THE Contact model SHALL reject the transition with a validation error
6. WHEN a contact attempts to transition from 'failed' to 'pending', THE Contact model SHALL allow the transition for retry scenarios

### Requirement 2

**User Story:** As a developer, I want tests for the LookupRequestJob idempotency, so that I can ensure duplicate API calls are prevented.

#### Acceptance Criteria

1. WHEN LookupRequestJob processes a contact with status 'pending', THE LookupRequestJob SHALL mark the contact as 'processing' and perform the lookup
2. WHEN LookupRequestJob processes a contact with status 'completed', THE LookupRequestJob SHALL skip processing and return early
3. WHEN LookupRequestJob processes a contact with status 'processing', THE LookupRequestJob SHALL skip processing to prevent duplicate work
4. WHEN two concurrent LookupRequestJobs attempt to process the same contact, THE LookupRequestJob SHALL ensure only one job performs the API call

### Requirement 3

**User Story:** As a developer, I want tests for duplicate detection fingerprinting, so that I can ensure contacts are correctly identified as duplicates.

#### Acceptance Criteria

1. WHEN a contact's phone number is updated, THE Contact model SHALL recalculate the phone fingerprint
2. WHEN two contacts have the same formatted phone number, THE Contact model SHALL generate identical phone fingerprints
3. WHEN two contacts have different formatted phone numbers, THE Contact model SHALL generate different phone fingerprints
4. WHEN a contact's name fields are updated, THE Contact model SHALL recalculate the name fingerprint
5. WHEN fingerprints are calculated, THE Contact model SHALL use a consistent SHA-256 hashing algorithm

### Requirement 4

**User Story:** As a developer, I want tests for the TwilioCredential singleton pattern, so that I can ensure only one credential record exists.

#### Acceptance Criteria

1. WHEN TwilioCredential.current is called, THE TwilioCredential model SHALL return the singleton instance
2. WHEN attempting to create a second TwilioCredential record, THE TwilioCredential model SHALL reject the creation with a validation error
3. WHEN TwilioCredential is updated, THE TwilioCredential model SHALL invalidate the cache
4. WHEN TwilioCredential.current is called multiple times within the TTL period, THE TwilioCredential model SHALL return cached results

### Requirement 5

**User Story:** As a developer, I want tests for webhook error handling, so that I can ensure Twilio webhooks are always acknowledged.

#### Acceptance Criteria

1. WHEN a valid webhook is received, THE WebhooksController SHALL return HTTP 200 and create a Webhook record
2. WHEN webhook creation fails due to validation errors, THE WebhooksController SHALL return HTTP 200 and log the error
3. WHEN an unexpected error occurs during webhook processing, THE WebhooksController SHALL return HTTP 200 to prevent retry storms
4. WHEN a webhook with duplicate MessageSid is received, THE WebhooksController SHALL handle it gracefully without raising errors

### Requirement 6

**User Story:** As a developer, I want a test factory setup for Contact and related models, so that I can easily create test data.

#### Acceptance Criteria

1. WHEN FactoryBot builds a contact, THE Contact factory SHALL generate valid phone numbers in E.164 format
2. WHEN FactoryBot creates a contact, THE Contact factory SHALL support traits for different statuses (pending, processing, completed, failed)
3. WHEN FactoryBot creates a contact with business data, THE Contact factory SHALL support a :with_business trait
4. WHEN FactoryBot creates a twilio_credential, THE TwilioCredential factory SHALL generate valid Account SID (AC + 32 hex chars) and Auth Token formats

### Requirement 7

**User Story:** As a developer, I want tests for the CircuitBreakerService, so that I can ensure external API failures are handled gracefully.

#### Acceptance Criteria

1. WHEN an external API call succeeds, THE CircuitBreakerService SHALL return the response and keep the circuit closed
2. WHEN an external API call fails repeatedly, THE CircuitBreakerService SHALL open the circuit after the threshold is reached
3. WHEN the circuit is open, THE CircuitBreakerService SHALL raise CircuitOpenError without making the API call
4. WHEN the circuit is open and the timeout expires, THE CircuitBreakerService SHALL allow a test request through (half-open state)
5. WHEN CircuitBreakerService.reset is called, THE CircuitBreakerService SHALL close the circuit and clear failure counts

### Requirement 8

**User Story:** As a developer, I want tests for error handling in enrichment services, so that I can ensure failures don't crash the enrichment pipeline.

#### Acceptance Criteria

1. WHEN BusinessEnrichmentService encounters an API error, THE BusinessEnrichmentService SHALL log the error and return gracefully without raising
2. WHEN EmailEnrichmentService receives invalid response data, THE EmailEnrichmentService SHALL handle the error and preserve existing contact data
3. WHEN an enrichment service times out, THE enrichment service SHALL respect the configured timeout and return without blocking indefinitely
4. WHEN multiple enrichment providers are configured, THE enrichment service SHALL fallback to the next provider on failure

### Requirement 9

**User Story:** As a developer, I want tests for the callback recursion fix in Contact model, so that I can ensure fingerprint updates don't cause infinite loops.

#### Acceptance Criteria

1. WHEN a contact's phone number is updated, THE Contact model SHALL update fingerprints using update_columns to skip callbacks
2. WHEN fingerprints are recalculated, THE Contact model SHALL complete without triggering additional after_save callbacks
3. WHEN bulk updating contacts, THE Contact model SHALL complete within acceptable time limits without callback storms

### Requirement 10

**User Story:** As a developer, I want tests for the API v1 contacts endpoint, so that I can ensure the REST API works correctly.

#### Acceptance Criteria

1. WHEN a GET request is made to /api/v1/contacts with valid Bearer token, THE ContactsController SHALL return paginated contacts with HTTP 200
2. WHEN a GET request is made to /api/v1/contacts without authentication, THE ContactsController SHALL return HTTP 401
3. WHEN a POST request creates a new contact, THE ContactsController SHALL validate the phone number format before creation
4. WHEN a GET request is made to /api/v1/contacts/:id, THE ContactsController SHALL return the contact details with HTTP 200 or HTTP 404 if not found

### Requirement 11

**User Story:** As a developer, I want integration tests for the complete lookup flow, so that I can verify the end-to-end process works.

#### Acceptance Criteria

1. WHEN a contact is created and LookupRequestJob runs, THE integration test SHALL verify the contact progresses through all status states
2. WHEN the lookup completes successfully, THE integration test SHALL verify enrichment jobs are queued
3. WHEN the Twilio API returns an error, THE integration test SHALL verify the contact is marked as failed with error details stored
