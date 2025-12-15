# Error Handling Guidelines

## Overview

This guide establishes consistent error handling patterns across the Twilio Bulk Lookup application. Proper error handling improves debugging, reliability, and maintainability.

## Core Principles

### 1. **Never Swallow Errors Silently**
Always log errors before returning or continuing execution.

```ruby
# ❌ BAD - Silent failure
rescue StandardError => e
  false
end

# ✅ GOOD - Log before returning
rescue StandardError => e
  Rails.logger.error("Operation failed: #{e.class} - #{e.message}")
  false
end
```

### 2. **Include Context in Error Messages**
Error logs should include enough information to debug without additional queries.

```ruby
# ❌ BAD - No context
Rails.logger.error("Sync failed: #{e.message}")

# ✅ GOOD - Rich context
Rails.logger.error(
  "Salesforce sync failed for contact #{@contact.id} (operation: #{operation}, " \
  "salesforce_id: #{@contact.salesforce_id || 'none'}): #{e.class} - #{e.message}"
)
```

### 3. **Log Error Class, Not Just Message**
Always log `e.class` to distinguish between different error types.

```ruby
# ❌ BAD - Only message
Rails.logger.error("Error: #{e.message}")

# ✅ GOOD - Class and message
Rails.logger.error("Error: #{e.class} - #{e.message}")
```

### 4. **Include Stack Traces for Unexpected Errors**
For non-routine errors, include the first 3-5 lines of the backtrace.

```ruby
rescue StandardError => e
  Rails.logger.error("Unexpected error: #{e.class} - #{e.message}")
  Rails.logger.error(e.backtrace.first(5).join("\n"))
  raise
end
```

---

## Pattern-Specific Guidelines

### Background Jobs

**Pattern:** Broad rescue at entry point, specific rescues inside operations.

```ruby
class MyJob < ApplicationJob
  queue_as :default

  # Use ActiveJob retry configuration
  retry_on StandardError, wait: ->(executions) { (executions ** 4) + rand(30) }, attempts: 3

  # Discard on permanent failures
  discard_on ActiveRecord::RecordNotFound do |job, exception|
    Rails.logger.error("[MyJob] Record not found: #{exception.message}")
  end

  def perform(resource_id)
    resource = Resource.find(resource_id)

    # Perform work...

  rescue StandardError => e
    # Log with context including retry attempt
    Rails.logger.error(
      "[MyJob] Error processing resource #{resource_id} (attempt: #{executions}): " \
      "#{e.class} - #{e.message}"
    )
    Rails.logger.error(e.backtrace.first(5).join("\n"))
    raise # Re-raise to trigger retry logic
  end
end
```

**Key Points:**
- Use `executions` to track retry attempts
- Log before re-raising
- Include resource ID and operation context
- Use `retry_on` and `discard_on` for declarative retry logic

---

### Service Objects

**Pattern:** Specific exceptions for expected failures, general rescue for safety.

```ruby
class MyService
  def perform
    # Main logic
    result = api_call

    if result
      update_resource(result)
      true
    else
      Rails.logger.info("No data found for #{@resource.id}")
      false
    end
  rescue HttpClient::TimeoutError => e
    Rails.logger.warn("API timeout for #{@resource.id}: #{e.message}")
    nil
  rescue HttpClient::CircuitOpenError => e
    Rails.logger.warn("Circuit open for #{@resource.id}: #{e.message}")
    nil
  rescue StandardError => e
    Rails.logger.error(
      "Service error for #{@resource.id}: #{e.class} - #{e.message}"
    )
    Rails.logger.error(e.backtrace.first(3).join("\n"))
    false
  end
end
```

**Key Points:**
- Rescue specific exceptions first (timeout, circuit breaker, etc.)
- Use appropriate log levels: `info` for expected no-ops, `warn` for retryable issues, `error` for failures
- Include resource identifiers in all log messages
- Return meaningful values (true/false/nil) to indicate different outcomes

---

### API Client Methods

**Pattern:** Distinguish between timeout, circuit breaker, parsing, and unexpected errors.

```ruby
def api_call
  response = HttpClient.get(uri, circuit_name: 'my-service') do |request|
    request['Authorization'] = "Bearer #{api_key}"
  end

  return nil unless response.code == '200'

  data = JSON.parse(response.body)
  parse_response(data)

rescue HttpClient::TimeoutError => e
  Rails.logger.warn("API timeout (endpoint: #{uri.host}): #{e.message}")
  nil
rescue HttpClient::CircuitOpenError => e
  Rails.logger.warn("Circuit open (endpoint: #{uri.host}): #{e.message}")
  nil
rescue JSON::ParserError => e
  Rails.logger.error("Invalid JSON from API (endpoint: #{uri.host}): #{e.message}")
  nil
rescue StandardError => e
  Rails.logger.error("API error (endpoint: #{uri.host}): #{e.class} - #{e.message}")
  nil
end
```

**Key Points:**
- Use HttpClient with circuit breaker for external APIs
- Rescue specific HTTP errors first
- Log the API endpoint/service name for context
- Return `nil` for all failure cases (don't raise unless critical)

---

### Controllers

**Pattern:** Catch specific exceptions, provide user feedback, log for debugging.

```ruby
def create
  @resource = Resource.create!(resource_params)
  redirect_to @resource, notice: "Created successfully"

rescue ActiveRecord::RecordInvalid => e
  flash.now[:alert] = "Validation failed: #{e.message}"
  render :new

rescue Twilio::REST::RestError => e
  Rails.logger.error("Twilio API error (user: #{current_user.id}): #{e.message}")
  redirect_to resources_path, alert: "Service temporarily unavailable"

rescue StandardError => e
  Rails.logger.error(
    "Unexpected error in ResourcesController#create (user: #{current_user.id}): " \
    "#{e.class} - #{e.message}"
  )
  Rails.logger.error(e.backtrace.first(5).join("\n"))
  redirect_to resources_path, alert: "An error occurred"
end
```

**Key Points:**
- Rescue specific exceptions for better UX
- Always log before redirecting
- Include user context (user ID, params) when safe
- Generic user messages for unexpected errors, detailed logs for debugging

---

### Admin Panels

**Pattern:** Graceful degradation with logging for diagnostics.

```ruby
row("Service Status") do
  begin
    status = check_service_status
    status_tag status, class: status == 'connected' ? 'completed' : 'failed'
  rescue StandardError => e
    Rails.logger.warn("Admin service check failed: #{e.class} - #{e.message}")
    status_tag "Error: #{e.message}", class: "failed"
  end
end
```

**Key Points:**
- Use `warn` level for non-critical admin checks
- Display user-friendly error in UI
- Log full error details for debugging
- Don't let admin panel errors break the page

---

### Model Callbacks

**Pattern:** Log but don't raise (callbacks should be idempotent).

```ruby
after_save :broadcast_change, if: :should_broadcast?

def broadcast_change
  # Check throttle, broadcast to ActionCable...
rescue StandardError => e
  Rails.logger.warn(
    "Broadcast failed for #{self.class.name} #{id}: #{e.class} - #{e.message}"
  )
  # Don't re-raise - broadcast failure shouldn't fail the save
end
```

**Key Points:**
- Use `warn` level for non-critical side effects
- Include model class and ID
- Never raise from non-essential callbacks
- Essential callbacks should raise to prevent invalid state

---

## Log Levels

Use appropriate log levels for different situations:

| Level | Usage | Example |
|-------|-------|---------|
| `debug` | Detailed flow tracking | "Entering method X with params Y" |
| `info` | Normal operations | "Successfully enriched contact 123" |
| `warn` | Recoverable issues | "API timeout, will retry" |
| `error` | Failed operations | "Sync failed for contact 123" |

---

## Error Context Checklist

Always include these in error logs:

- [ ] **Resource ID** - Which record failed? (contact_id, webhook_id, etc.)
- [ ] **Operation** - What was being attempted? (create, update, sync)
- [ ] **Error Class** - Use `e.class` not just `e.message`
- [ ] **Retry Context** - For jobs: attempt number (`executions`)
- [ ] **Service Name** - For API calls: which external service?
- [ ] **Stack Trace** - For unexpected errors: first 3-5 lines

---

## Anti-Patterns to Avoid

### ❌ Empty Rescue Blocks
```ruby
# Never do this
begin
  risky_operation
rescue
  # Silent failure
end
```

### ❌ Rescuing Exception
```ruby
# Too broad - catches SystemExit, SignalException, etc.
rescue Exception => e
  # This is almost never what you want
end
```

### ❌ Missing Context
```ruby
# Can't debug this without more info
rescue StandardError => e
  Rails.logger.error(e.message)
end
```

### ❌ Logging Without Error Class
```ruby
# Don't know if it's timeout, validation, or something else
Rails.logger.error("Failed: #{e.message}")
```

---

## Testing Error Handling

Ensure your error handlers are tested:

```ruby
RSpec.describe MyService do
  it 'logs and returns false on API timeout' do
    allow(HttpClient).to receive(:get).and_raise(HttpClient::TimeoutError)

    expect(Rails.logger).to receive(:warn).with(/API timeout/)
    expect(service.perform).to be_nil
  end

  it 'includes resource ID in error log' do
    allow(service).to receive(:api_call).and_raise(StandardError, "boom")

    expect(Rails.logger).to receive(:error).with(/resource #{resource.id}/)
    service.perform
  end
end
```

---

## Migration Path

When improving existing error handling:

1. **Add logging** - Never remove errors without adding logs
2. **Add context** - Enhance logs with resource IDs and operation type
3. **Add error class** - Change `e.message` to `#{e.class} - #{e.message}`
4. **Add stack traces** - For unexpected errors, include backtrace
5. **Test** - Ensure logs appear correctly in tests

---

## Examples from Codebase

### Good Example: BusinessEnrichmentJob
```ruby
retry_on StandardError, wait: ->(executions) { (executions ** 4) + rand(30) }, attempts: 2 do |job, exception|
  contact_id = job.arguments.first
  contact = Contact.find_by(id: contact_id)
  Rails.logger.warn("Business enrichment failed for contact #{contact_id}: #{exception.message}")
end

discard_on ActiveRecord::RecordNotFound do |job, exception|
  Rails.logger.error("Contact not found for enrichment: #{exception.message}")
end
```

### Good Example: Webhook Processing
```ruby
rescue StandardError => e
  update!(
    status: 'failed',
    processing_error: e.message,
    retry_count: (retry_count || 0) + 1
  )
  Rails.logger.error(
    "Webhook processing failed (webhook_id: #{id}, source: #{source}, " \
    "retry_count: #{retry_count || 0}): #{e.class} - #{e.message}"
  )
  raise
end
```

### Good Example: CRM Sync Service
```ruby
rescue StandardError => e
  operation = @contact.salesforce_id.present? ? 'update' : 'create'
  Rails.logger.error(
    "Salesforce sync error for contact #{@contact.id} (operation: #{operation}, " \
    "salesforce_id: #{@contact.salesforce_id || 'none'}): #{e.class} - #{e.message}"
  )
  Rails.logger.error(e.backtrace.first(3).join("\n"))
  { success: false, error: e.message }
end
```

---

## Quick Reference

**Job Error Template:**
```ruby
rescue StandardError => e
  Rails.logger.error(
    "[JobName] Error for resource #{id} (attempt: #{executions}): #{e.class} - #{e.message}"
  )
  Rails.logger.error(e.backtrace.first(5).join("\n"))
  raise
end
```

**Service Error Template:**
```ruby
rescue StandardError => e
  Rails.logger.error(
    "Service error for #{@resource.id} (operation: #{op}): #{e.class} - #{e.message}"
  )
  Rails.logger.error(e.backtrace.first(3).join("\n"))
  false
end
```

**Controller Error Template:**
```ruby
rescue StandardError => e
  Rails.logger.error(
    "Controller error in #{controller_name}##{action_name}: #{e.class} - #{e.message}"
  )
  redirect_to fallback_path, alert: "An error occurred"
end
```

---

## Summary

1. **Always log** - Never swallow errors silently
2. **Add context** - Include IDs, operation type, retry count
3. **Use error class** - Log `e.class` not just `e.message`
4. **Include stack traces** - For unexpected errors
5. **Choose appropriate log levels** - info/warn/error based on severity
6. **Test error handling** - Verify logs appear correctly

Following these patterns ensures errors are traceable, debuggable, and lead to faster incident resolution.
