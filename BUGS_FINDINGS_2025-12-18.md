# Bugs and Findings Report
Date: 2025-12-18
Scope: twilio-bulk-lookup-master
Method: PHANTOM Review Path (R1-R5)

## 1) [Critical] Dashboard stats refresh trigger fails inside transaction
Refs: db/migrate/20251215082933_create_dashboard_stats_view.rb:83
R1 (Potential Symptom): Any insert/update/delete on contacts can raise an error and abort the write.
R2 (Ghost vs Demon): Intended auto-refresh vs actual "REFRESH MATERIALIZED VIEW CONCURRENTLY" inside trigger, which PostgreSQL disallows in a transaction.
R3 (Assumption): Concurrent refresh is safe inside triggers.
R4 (Adversarial Input): Any contact write while trigger is active.
R5 (Defense): Remove the trigger and refresh asynchronously after commit, or use non-concurrent refresh outside write transactions.

## 2) [High] API create can strand contacts in processing
Refs: app/controllers/api/v1/contacts_controller.rb:32, app/jobs/lookup_request_job.rb:47
R1: API-created contact stays in processing and never runs lookup.
R2: Controller sets status to processing; job only processes pending/failed.
R3: Assumes controller can pre-mark processing.
R4: POST /api/v1/contacts with a valid phone number.
R5: Let the job handle the status transition; remove mark_processing! from controller or allow processing state in job gate.

## 3) [High] Parallel enrichment mutates one ActiveRecord object across threads
Refs: app/services/parallel_enrichment_service.rb:71
R1: Intermittent lost updates, stale writes, or thread-safety errors under load.
R2: Ghost: parallel API calls safely update one contact. Demon: same AR instance shared across promises.
R3: Assumes ActiveRecord objects are thread-safe.
R4: Multiple enrichments enabled for the same contact.
R5: Pass contact_id into each thread and reload inside, or serialize updates with per-contact locking.

## 4) [High] Quality score can exceed DB constraint
Refs: app/models/concerns/contact/duplicate_detection.rb:56, db/schema.rb:328
R1: Save fails with check constraint violation on data_quality_score.
R2: Ghost: score 0-100. Demon: scoring can reach 105.
R3: Assumes scoring cannot exceed 100.
R4: Fully enriched business with verified email, name, website, position, and low risk.
R5: Clamp to 100 before update_columns, or adjust scoring weights.

## 5) [Medium] HttpClient shares Net::HTTP connections across threads
Refs: lib/http_client.rb:43
R1: Rare request corruption or IOErrors with concurrent calls to the same host.
R2: Ghost: shared connection pool is safe. Demon: Net::HTTP is not thread-safe.
R3: Assumes Net::HTTP can be reused across threads without locks.
R4: Concurrent API calls to the same host via HttpClient.
R5: Use per-thread connections, synchronize access, or adopt a thread-safe HTTP client.

## 6) [Medium] Partial credentials can mix sources
Refs: config/initializers/app_config.rb:82, app/jobs/lookup_request_job.rb:66
R1: Auth failures when credentials.yml has account SID but missing auth token.
R2: Ghost: a single credential source is used. Demon: SID from encrypted creds + token from DB.
R3: Assumes encrypted creds always include both keys.
R4: Encrypted credentials missing auth_token, DB has auth_token present.
R5: Require both keys before selecting a source; do not mix across sources.

## 7) [Low] AI SMS options not forwarded correctly
Refs: app/services/messaging_service.rb:100
R1: AI outreach ignores custom model/temperature options.
R2: Ghost: options pass through. Demon: options nested under :options key.
R3: Assumes keyword hash auto-splats.
R4: send_ai_generated_sms with options.
R5: Call generate_outreach_message(..., **options).

## 8) [Low] Webhook processing ordering/limit not respected
Refs: app/models/webhook.rb:73
R1: Pending webhooks processed out of order or beyond limit.
R2: Ghost: oldest 100 processed. Demon: find_each ignores order/limit.
R3: Assumes find_each preserves scope order and limit.
R4: Large backlog of pending webhooks.
R5: Use limit(100).each or in_batches(of: 100).order(:received_at).

## 9) [Low] Business lookup retries on permanent config errors
Refs: app/jobs/business_lookup_job.rb:4, app/services/business_lookup_service.rb:94
R1: Jobs retry endlessly when no Yelp/Google keys are configured.
R2: Ghost: config error fails fast. Demon: ProviderError is retried as StandardError.
R3: Assumes ProviderError is transient.
R4: Missing business directory API keys.
R5: discard_on ProviderError or mark lookup failed without raising.
