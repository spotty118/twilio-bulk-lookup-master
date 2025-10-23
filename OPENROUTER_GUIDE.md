# OpenRouter Integration Guide

## What is OpenRouter?

OpenRouter is a unified API that provides access to 100+ AI models from multiple providers through a single endpoint. Instead of managing separate API keys and integrations for OpenAI, Anthropic, Google, Meta, and others, you can use OpenRouter to access them all.

**Key Benefits:**
- ✅ **Single API Key** - Access 100+ models with one key
- ✅ **Automatic Fallbacks** - If one model is down, automatically try alternatives
- ✅ **Cost Optimization** - Pay-as-you-go with competitive pricing
- ✅ **Model Comparison** - Easily test and compare different models
- ✅ **No Provider Lock-in** - Switch models without code changes
- ✅ **Usage Analytics** - Built-in tracking and cost reports

---

## Setup Instructions

### 1. Get Your OpenRouter API Key

1. Go to https://openrouter.ai
2. Sign up or log in
3. Navigate to **Keys** in your dashboard
4. Click **Create Key**
5. Copy your API key (starts with `sk-or-v1-`)

**Free Tier**: OpenRouter provides $1 in free credits to start testing.

### 2. Configure in Twilio Bulk Lookup

Navigate to **Admin → Twilio Credentials** and add:

```ruby
# Required
openrouter_api_key: "sk-or-v1-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
enable_openrouter: true

# Optional - Model selection (default: openai/gpt-4o-mini)
openrouter_model: "openai/gpt-4o-mini"

# Optional - For OpenRouter rankings (helps them improve)
openrouter_site_url: "https://yourdomain.com"
openrouter_site_name: "Your App Name"

# Set as preferred provider (optional)
preferred_llm_provider: "openrouter"
```

---

## Available Models

OpenRouter provides access to 100+ models. Here are some popular choices:

### **Recommended for Contact Intelligence**

**1. Fast & Cheap (Best for most queries)**
```ruby
openrouter_model: "google/gemini-flash-1.5"
# Cost: ~$0.075 per 1M input tokens, $0.30 per 1M output tokens
# Speed: ⚡⚡⚡ Very Fast
# Best for: Quick lookups, simple queries, batch processing
```

**2. Balanced Performance**
```ruby
openrouter_model: "openai/gpt-4o-mini"
# Cost: ~$0.15 per 1M input tokens, $0.60 per 1M output tokens
# Speed: ⚡⚡ Fast
# Best for: General purpose, most use cases
```

**3. High Quality (Best for complex analysis)**
```ruby
openrouter_model: "anthropic/claude-3.5-sonnet"
# Cost: ~$3 per 1M input tokens, $15 per 1M output tokens
# Speed: ⚡ Slower
# Best for: Deep sales intelligence, complex reasoning
```

**4. Budget Option (Cheapest)**
```ruby
openrouter_model: "meta-llama/llama-3.1-8b-instruct:free"
# Cost: FREE (rate-limited)
# Speed: ⚡⚡⚡ Very Fast
# Best for: Testing, high-volume simple queries
```

### **Full Model List**

View all available models at: https://openrouter.ai/models

Popular categories:
- **OpenAI**: GPT-4, GPT-4 Turbo, GPT-3.5
- **Anthropic**: Claude 3.5 Sonnet, Claude 3 Opus, Claude 3 Haiku
- **Google**: Gemini 1.5 Pro, Gemini 1.5 Flash
- **Meta**: Llama 3.1 (8B, 70B, 405B)
- **Mistral**: Mistral Large, Mistral Medium
- **Others**: Cohere, Perplexity, and more

---

## Usage Examples

### Basic Query with OpenRouter

```ruby
# Use OpenRouter explicitly
llm = MultiLlmService.new
result = llm.generate("Analyze this contact...", provider: 'openrouter')

# Or set as default in credentials
llm = MultiLlmService.new
result = llm.generate("Analyze this contact...")
# Uses preferred_llm_provider setting
```

### Natural Language Search

```ruby
service = AiAssistantService.new
result = service.natural_language_search(
  "Find tech companies in California with 50+ employees",
  provider: 'openrouter'
)
```

### Sales Intelligence

```ruby
result = AiAssistantService.generate_sales_intelligence(
  contact,
  provider: 'openrouter'
)
```

### Using Specific Models

```ruby
# Use Claude via OpenRouter
result = llm.generate(
  "Complex analysis prompt...",
  provider: 'openrouter',
  model: 'anthropic/claude-3.5-sonnet'
)

# Use free Llama model
result = llm.generate(
  "Simple query...",
  provider: 'openrouter',
  model: 'meta-llama/llama-3.1-8b-instruct:free'
)
```

---

## OpenRouter-Specific Features

### 1. Automatic Fallbacks

OpenRouter can automatically fall back to alternative models if your primary choice is unavailable:

```ruby
result = llm.generate(
  "Your prompt",
  provider: 'openrouter',
  route: 'fallback'  # Automatically try alternatives if primary fails
)
```

**Fallback Priority:**
1. Your specified model
2. Similar models from same provider
3. Alternative providers with similar capabilities

### 2. Middle-Out Optimization

OpenRouter can optimize responses for cost/quality:

```ruby
result = llm.generate(
  "Your prompt",
  provider: 'openrouter',
  transforms: ['middle-out']  # Optimize token usage
)
```

### 3. Model Routing

Choose routing strategy:

```ruby
# 'fallback' - Try alternatives if primary fails (recommended)
route: 'fallback'

# Default - Use specified model only
route: nil
```

---

## Cost Comparison

### Per 1 Million Tokens (Prompt + Completion)

| Provider | Model | Input Cost | Output Cost | Total (avg) |
|----------|-------|-----------|-------------|-------------|
| OpenRouter | Llama 3.1 8B (free) | $0 | $0 | **$0** |
| OpenRouter | Gemini Flash | $0.075 | $0.30 | **~$0.19** |
| OpenRouter | GPT-4o Mini | $0.15 | $0.60 | **~$0.38** |
| OpenRouter | Claude 3.5 Sonnet | $3.00 | $15.00 | **~$9.00** |

**Typical Contact Query:**
- Average tokens per query: ~500-1000 tokens
- Cost per query with Gemini Flash: **~$0.0002** (2 cents per 100 queries)
- Cost per query with Llama 3.1 (free): **$0**

### Cost Optimization Tips

**1. Use Free Models for Simple Queries**
```ruby
# For simple lookups, use free Llama
openrouter_model: "meta-llama/llama-3.1-8b-instruct:free"
```

**2. Use Fallbacks to Prevent Failures**
```ruby
# Primary: Fast free model
# Fallback: Paid model if free is rate-limited
route: 'fallback'
```

**3. Batch Processing**
```ruby
# Process multiple contacts at once to reduce overhead
contacts.each_slice(10) do |batch|
  # Process batch with single API call
end
```

**4. Model Selection by Task**
```ruby
# Quick queries → Free Llama or Gemini Flash
# Complex analysis → Claude 3.5 Sonnet
# Balanced → GPT-4o Mini

provider = AiAssistantService.best_provider_for(:quick_query)
# Returns 'openrouter' with Gemini model
```

---

## Monitoring & Analytics

### View OpenRouter Usage

```ruby
# All OpenRouter calls
ApiUsageLog.by_provider('openrouter')

# Cost this month
ApiUsageLog.openrouter.this_month.sum(:cost)

# Usage by model
ApiUsageLog.where(provider: 'openrouter')
           .group(:service)
           .sum(:cost)
```

### OpenRouter Dashboard

View detailed usage on OpenRouter's dashboard:
1. Go to https://openrouter.ai/activity
2. See per-model costs
3. View usage graphs
4. Download reports

---

## Advanced Configuration

### Model Parameters

```ruby
result = llm.generate(
  "Your prompt",
  provider: 'openrouter',
  model: 'openai/gpt-4o-mini',
  temperature: 0.7,        # Creativity (0-1)
  max_tokens: 500,         # Response length
  route: 'fallback',       # Automatic fallbacks
  transforms: ['middle-out'] # Cost optimization
)
```

### Multiple Models Comparison

```ruby
models = [
  'google/gemini-flash-1.5',
  'openai/gpt-4o-mini',
  'anthropic/claude-3.5-sonnet'
]

results = models.map do |model|
  llm.generate(
    "Your prompt",
    provider: 'openrouter',
    model: model
  )
end

# Compare responses and pick best
```

---

## Rate Limits

OpenRouter rate limits vary by model:

**Free Models:**
- Llama 3.1 8B: 20 requests/minute
- Gemini Flash (paid): 1000 requests/minute

**Paid Models:**
- GPT-4o Mini: 500 requests/minute
- Claude 3.5 Sonnet: 50 requests/minute

**Recommendations:**
- Use fallback routing to avoid rate limit errors
- Implement exponential backoff for retries
- Monitor usage in ApiUsageLog

---

## Troubleshooting

### Common Issues

**1. "No OpenRouter API key configured"**
```ruby
# Solution: Add key in Twilio Credentials
openrouter_api_key: "sk-or-v1-xxxxx"
enable_openrouter: true
```

**2. "Model not found"**
```ruby
# Solution: Check model name format
# Correct: "openai/gpt-4o-mini"
# Wrong: "gpt-4o-mini"

# View all models: https://openrouter.ai/models
```

**3. "Rate limit exceeded"**
```ruby
# Solution: Use fallback routing
route: 'fallback'

# Or switch to paid model
openrouter_model: "openai/gpt-4o-mini"  # Higher limits
```

**4. "Insufficient credits"**
```ruby
# Solution: Add credits at https://openrouter.ai/credits
# Free tier: $1
# Paid: Add via credit card
```

### Debug Mode

```ruby
# Enable detailed logging
result = llm.generate(prompt, provider: 'openrouter')

# Check response metadata
puts result[:model_used]  # Actual model that processed request
puts result[:usage]       # Token usage details
puts result[:provider]    # Should be 'openrouter'
```

---

## Migration from Direct Provider APIs

### If Currently Using OpenAI

**Before:**
```ruby
openai_api_key: "sk-xxxxx"
preferred_llm_provider: "openai"
```

**After (OpenRouter):**
```ruby
openrouter_api_key: "sk-or-v1-xxxxx"
openrouter_model: "openai/gpt-4o-mini"  # Same model via OpenRouter
preferred_llm_provider: "openrouter"
```

**Benefits:**
- Keep using same models
- Add fallback options
- Access other models without new integrations
- Unified billing and analytics

### If Currently Using Anthropic

**Before:**
```ruby
anthropic_api_key: "sk-ant-xxxxx"
preferred_llm_provider: "anthropic"
```

**After (OpenRouter):**
```ruby
openrouter_api_key: "sk-or-v1-xxxxx"
openrouter_model: "anthropic/claude-3.5-sonnet"
preferred_llm_provider: "openrouter"
```

---

## Best Practices

### 1. Start with Free Tier
```ruby
# Test with free model first
openrouter_model: "meta-llama/llama-3.1-8b-instruct:free"
enable_openrouter: true
```

### 2. Use Fallbacks
```ruby
# Always enable fallback routing
route: 'fallback'
# Prevents failures if model is down
```

### 3. Monitor Costs
```ruby
# Check daily
ApiUsageLog.openrouter.today.sum(:cost)

# Set up alerts for high usage
if ApiUsageLog.openrouter.today.sum(:cost) > 10
  # Alert admin
end
```

### 4. Choose Right Model for Task
```ruby
# Simple queries → Gemini Flash (fast + cheap)
# Complex analysis → Claude 3.5 (quality)
# Batch processing → Llama 3.1 Free (no cost)
```

### 5. Keep Direct APIs as Backup
```ruby
# Keep your existing API keys configured
# OpenRouter can fail back to direct APIs if needed
openai_api_key: "sk-xxxxx"  # Keep as backup
openrouter_api_key: "sk-or-v1-xxxxx"  # Primary
```

---

## FAQ

**Q: Do I need other API keys if I use OpenRouter?**
A: No! OpenRouter provides access to all models through its own API. However, keeping direct API keys as backups is recommended.

**Q: Which model should I use?**
A: For most contact intelligence queries, use `google/gemini-flash-1.5` (fast + cheap). For complex analysis, use `anthropic/claude-3.5-sonnet`.

**Q: How much does OpenRouter cost?**
A: Pay-as-you-go pricing per token. Free tier includes $1 credit. Costs vary by model (see Cost Comparison above).

**Q: Can I use free models?**
A: Yes! `meta-llama/llama-3.1-8b-instruct:free` is completely free with rate limits.

**Q: What happens if a model fails?**
A: With `route: 'fallback'` enabled, OpenRouter automatically tries alternative models.

**Q: Can I switch models without code changes?**
A: Yes! Just change `openrouter_model` in credentials - no code changes needed.

**Q: How do I view my usage?**
A: Check ApiUsageLog in the app, or view OpenRouter dashboard at https://openrouter.ai/activity

---

## Quick Start Checklist

- [ ] Sign up at https://openrouter.ai
- [ ] Get API key from dashboard
- [ ] Add `openrouter_api_key` to Twilio Credentials
- [ ] Set `enable_openrouter: true`
- [ ] Choose model (recommend: `google/gemini-flash-1.5`)
- [ ] Set `preferred_llm_provider: "openrouter"` (optional)
- [ ] Test with simple query
- [ ] Monitor costs in ApiUsageLog
- [ ] Enable fallback routing for reliability

---

## Support & Resources

- **OpenRouter Documentation**: https://openrouter.ai/docs
- **Available Models**: https://openrouter.ai/models
- **Pricing**: https://openrouter.ai/docs#models
- **Dashboard**: https://openrouter.ai/activity
- **Discord Community**: https://discord.gg/openrouter

---

**Last Updated**: October 2025
**Version**: 1.0.0
**Integration Status**: ✅ Complete and tested
