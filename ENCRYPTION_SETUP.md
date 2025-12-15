# ActiveRecord Encryption Setup Guide

## Overview

This application uses Rails 7's built-in ActiveRecord encryption to protect sensitive data like API keys and authentication tokens stored in the database.

## ⚠️ CRITICAL: Generate Encryption Keys

Before running the application, you **MUST** generate encryption keys. Without these, the application will fail to boot.

### Step 1: Generate Keys

Run this command to generate your encryption keys:

```bash
rails db:encryption:init
```

This will output something like:

```
active_record_encryption:
  primary_key: EGY8WhulUOXixybod7ZWwMIL68R9o5kC
  deterministic_key: aPA5XyALhf75NNnMzaspW7akTfZp0lPN
  key_derivation_salt: xEY0dt6TZcAMg52K7O84wYzkjvbA62Hz
```

### Step 2: Store Keys Securely

You have three options for storing these keys:

#### Option A: Environment Variables (RECOMMENDED for Production)

Add to your `.env` file (for development) or hosting platform environment variables:

```bash
export ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=EGY8WhulUOXixybod7ZWwMIL68R9o5kC
export ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=aPA5XyALhf75NNnMzaspW7akTfZp0lPN
export ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=xEY0dt6TZcAMg52K7O84wYzkjvbA62Hz
```

For **Heroku**:

```bash
heroku config:set ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=EGY8WhulUOXixybod7ZWwMIL68R9o5kC
heroku config:set ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=aPA5XyALhf75NNnMzaspW7akTfZp0lPN
heroku config:set ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=xEY0dt6TZcAMg52K7O84wYzkjvbA62Hz
```

#### Option B: Rails Credentials (Alternative)

Store in encrypted credentials file:

```bash
EDITOR="code --wait" rails credentials:edit
```

Add this to the credentials file:

```yaml
active_record_encryption:
  primary_key: EGY8WhulUOXixybod7ZWwMIL68R9o5kC
  deterministic_key: aPA5XyALhf75NNnMzaspW7akTfZp0lPN
  key_derivation_salt: xEY0dt6TZcAMg52K7O84wYzkjvbA62Hz
```

**Note:** You'll need to commit `config/credentials.yml.enc` but keep `config/master.key` secret.

#### Option C: Docker Environment

For Docker deployments, add to `docker-compose.yml` or dockerfile ENV:

```yaml
environment:
  - ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=${ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY}
  - ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=${ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY}
  - ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=${ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT}
```

## 🔐 Security Best Practices

### DO ✅

- **Generate different keys for each environment** (development, staging, production)
- **Back up keys securely** before deploying to production
- **Store keys in a password manager** or secret management service (AWS Secrets Manager, HashiCorp Vault)
- **Rotate keys periodically** (see Key Rotation section below)
- **Restrict access** to keys to only essential personnel
- **Use environment variables** in production (never hardcode)

### DON'T ❌

- **Never commit keys** to version control (`.env`, `.env.production`, etc. are in `.gitignore`)
- **Never share keys** via email, Slack, or other insecure channels
- **Never use the same keys** across environments
- **Never log keys** or include them in error messages
- **Don't lose keys** - encrypted data becomes permanently unreadable

## 🔄 Key Rotation

If you need to rotate encryption keys (e.g., after a security incident):

### 1. Generate New Keys

```bash
rails db:encryption:init
```

### 2. Configure Previous Keys

Add the old keys to `config/initializers/active_record_encryption.rb`:

```ruby
config.active_record.encryption.previous = [{
  primary_key: "OLD_PRIMARY_KEY",
  deterministic_key: "OLD_DETERMINISTIC_KEY",
  key_derivation_salt: "OLD_SALT"
}]
```

### 3. Re-encrypt Data

Create a migration to re-encrypt existing data:

```ruby
class RotateEncryptionKeys < ActiveRecord::Migration[7.2]
  def up
    # Re-save encrypted records to use new keys
    TwilioCredential.find_each do |credential|
      credential.save!
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
```

### 4. Remove Old Keys

After successful re-encryption, remove the `previous` key configuration.

## 🧪 Verifying Encryption

Test that encryption is working:

```ruby
# In rails console
rails console

# Create a test credential
cred = TwilioCredential.create!(
  account_sid: 'ACtest',
  auth_token: 'test_secret_token_12345'
)

# Check encrypted value in database (should be gibberish)
result = ActiveRecord::Base.connection.execute(
  "SELECT auth_token FROM twilio_credentials WHERE id = #{cred.id}"
)
puts result.first['auth_token']
# => "{\"p\":\"encrypted_gibberish...\"}"

# Verify decryption works
cred.reload
puts cred.auth_token
# => "test_secret_token_12345"

# Cleanup
cred.destroy
```

## 📊 What Gets Encrypted

The following sensitive fields are encrypted in the `twilio_credentials` table:

- `auth_token` - Twilio authentication token
- `clearbit_api_key` - Clearbit API key
- `hunter_api_key` - Hunter.io API key
- `zerobounce_api_key` - ZeroBounce API key
- `openai_api_key` - OpenAI API key
- `anthropic_api_key` - Anthropic API key
- `google_ai_api_key` - Google AI API key
- `google_places_api_key` - Google Places API key
- `yelp_api_key` - Yelp API key
- `whitepages_api_key` - Whitepages Pro API key
- `truecaller_api_key` - TrueCaller API key
- `salesforce_client_secret` - Salesforce OAuth secret
- `salesforce_access_token` - Salesforce access token
- `salesforce_refresh_token` - Salesforce refresh token
- `hubspot_api_key` - HubSpot API key
- `pipedrive_api_key` - Pipedrive API key
- `verizon_api_key` - Verizon API key
- `verizon_api_secret` - Verizon API secret

See `config/initializers/active_record_encryption.rb` for implementation details.

## 🐛 Troubleshooting

### Error: "ActiveRecord::Encryption::Errors::Configuration"

**Cause:** Encryption keys not configured

**Fix:** Follow Step 1 and Step 2 above to generate and store keys

### Error: "ActiveRecord::Encryption::Errors::Decryption"

**Cause:** Trying to decrypt with wrong keys (keys were changed/lost)

**Fix:** 
- Restore original keys from backup
- Or drop and recreate database (⚠️ data loss!)
- Or restore from backup before key change

### Keys Don't Work After Deploy

**Cause:** Environment variables not set on hosting platform

**Fix:** 
- Verify env vars are set: `heroku config` or `echo $ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`
- Restart application after setting env vars

## 📚 Additional Resources

- [Rails Encryption Guide](https://guides.rubyonrails.org/active_record_encryption.html)
- [ActiveRecord Encryption API](https://api.rubyonrails.org/classes/ActiveRecord/Encryption.html)
- [OWASP Cryptographic Storage Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Cryptographic_Storage_Cheat_Sheet.html)

## 🆘 Emergency Recovery

If you lose your encryption keys:

1. **Check backups** - Password manager, secret service, old .env files
2. **Check deployed environments** - Production may still have working keys
3. **Contact team** - Someone else may have a copy
4. **Last resort** - Delete encrypted data and re-enter (⚠️ data loss)

**Prevention:** Always maintain secure backups of encryption keys separate from application backups.
