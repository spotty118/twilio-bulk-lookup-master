<?php

namespace App\Services;

use App\Models\TwilioCredential;
use App\Models\ApiUsageLog;
use GuzzleHttp\Client;
use GuzzleHttp\Exception\RequestException;
use GuzzleHttp\Exception\ConnectException;
use Illuminate\Support\Facades\Log;

/**
 * MultiLlmService - Unified interface for multiple LLM providers
 *
 * Supports:
 * - OpenAI (GPT-4, GPT-4o-mini)
 * - Anthropic Claude (Sonnet, Haiku, Opus)
 * - Google Gemini (Flash, Pro)
 * - OpenRouter (unified access to multiple models)
 *
 * Features:
 * - Provider selection and fallback
 * - Circuit breaker protection
 * - Token counting and cost calculation
 * - Response parsing and error handling
 * - Prompt sanitization to prevent injection attacks
 */
class MultiLlmService
{
    const OPENAI_API_URL = 'https://api.openai.com/v1/chat/completions';
    const ANTHROPIC_API_URL = 'https://api.anthropic.com/v1/messages';
    const GOOGLE_AI_API_URL = 'https://generativelanguage.googleapis.com/v1beta/models';
    const OPENROUTER_API_URL = 'https://openrouter.ai/api/v1/chat/completions';

    private $credentials;
    private $client;

    public function __construct()
    {
        $this->credentials = TwilioCredential::current();
        $this->client = new Client([
            'timeout' => 30,
            'connect_timeout' => 10,
        ]);
    }

    /**
     * Generate text using the preferred LLM provider
     *
     * @param string $prompt The prompt to send to the LLM
     * @param array $options Options: provider, model, max_tokens, temperature
     * @return array Response with success, response text, usage, and provider
     */
    public function generate(string $prompt, array $options = []): array
    {
        $provider = $options['provider'] ?? $this->credentials?->preferred_llm_provider ?? 'openai';

        switch ($provider) {
            case 'openai':
                return $this->generateWithOpenai($prompt, $options);
            case 'anthropic':
                return $this->generateWithAnthropic($prompt, $options);
            case 'google':
                return $this->generateWithGoogleAi($prompt, $options);
            case 'openrouter':
                return $this->generateWithOpenrouter($prompt, $options);
            default:
                return ['success' => false, 'error' => "Unknown LLM provider: {$provider}"];
        }
    }

    /**
     * Parse natural language query to search filters
     *
     * @param string $query Natural language query
     * @param array $options Options for LLM generation
     * @return array Parsed filters or error
     */
    public function parseQuery(string $query, array $options = []): array
    {
        $prompt = $this->buildQueryParsingPrompt($query);
        $result = $this->generate($prompt, array_merge($options, ['max_tokens' => 500]));

        if ($result['success']) {
            return $this->parseFilterResponse($result['response']);
        }

        return $result;
    }

    /**
     * Generate sales intelligence for a contact
     *
     * @param object $contact Contact model instance
     * @param array $options Options for LLM generation
     * @return array Sales intelligence or error
     */
    public function generateSalesIntelligence($contact, array $options = []): array
    {
        $prompt = $this->buildSalesIntelligencePrompt($contact);
        return $this->generate($prompt, array_merge($options, ['max_tokens' => 800]));
    }

    /**
     * Generate outreach message for a contact
     *
     * @param object $contact Contact model instance
     * @param string $messageType Type of message: intro, follow_up, email
     * @param array $options Options for LLM generation
     * @return array Outreach message or error
     */
    public function generateOutreachMessage($contact, string $messageType = 'intro', array $options = []): array
    {
        $prompt = $this->buildOutreachPrompt($contact, $messageType);
        return $this->generate($prompt, array_merge($options, ['max_tokens' => 300]));
    }

    // ========================================
    // OpenAI Integration
    // ========================================

    private function generateWithOpenai(string $prompt, array $options = []): array
    {
        if (!$this->credentials?->enable_ai_features) {
            return ['success' => false, 'error' => 'OpenAI not enabled'];
        }

        if (empty($this->credentials->openai_api_key)) {
            return ['success' => false, 'error' => 'No OpenAI API key configured'];
        }

        $startTime = microtime(true);
        $model = $options['model'] ?? $this->credentials->ai_model ?? 'gpt-4o-mini';
        $maxTokens = $options['max_tokens'] ?? $this->credentials->ai_max_tokens ?? 500;

        try {
            $body = [
                'model' => $model,
                'messages' => [
                    ['role' => 'system', 'content' => 'You are a helpful assistant for a contact intelligence platform.'],
                    ['role' => 'user', 'content' => $prompt]
                ],
                'max_tokens' => $maxTokens,
                'temperature' => $options['temperature'] ?? 0.7
            ];

            $response = CircuitBreakerService::call('openai', function() use ($body) {
                return $this->client->post(self::OPENAI_API_URL, [
                    'headers' => [
                        'Authorization' => 'Bearer ' . $this->credentials->openai_api_key,
                        'Content-Type' => 'application/json',
                    ],
                    'json' => $body,
                ]);
            });

            // Handle circuit breaker fallback
            if (is_array($response) && isset($response['circuit_open'])) {
                return ['success' => false, 'error' => $response['error']];
            }

            $responseTime = (int)((microtime(true) - $startTime) * 1000);

            if ($response->getStatusCode() == 200) {
                $data = json_decode($response->getBody()->getContents(), true);
                $text = $data['choices'][0]['message']['content'] ?? null;
                $usage = $data['usage'] ?? null;

                // Log API usage
                $this->logApiUsage([
                    'provider' => 'openai',
                    'service' => $model,
                    'status' => 'success',
                    'response_time_ms' => $responseTime,
                    'http_status_code' => 200,
                    'credits_used' => $usage['total_tokens'] ?? 0,
                    'response_data' => ['usage' => $usage],
                ]);

                return [
                    'success' => true,
                    'response' => $text,
                    'usage' => $usage,
                    'provider' => 'openai'
                ];
            }

            $errorData = json_decode($response->getBody()->getContents(), true);
            $errorMsg = $errorData['error']['message'] ?? 'OpenAI API error';

            $this->logApiUsage([
                'provider' => 'openai',
                'service' => $model,
                'status' => 'failed',
                'error_message' => $errorMsg,
                'response_time_ms' => $responseTime,
                'http_status_code' => $response->getStatusCode(),
            ]);

            return ['success' => false, 'error' => $errorMsg];

        } catch (ConnectException $e) {
            $responseTime = (int)((microtime(true) - $startTime) * 1000);
            Log::error("OpenAI API timeout: {$e->getMessage()}");

            $this->logApiUsage([
                'provider' => 'openai',
                'service' => $model,
                'status' => 'timeout',
                'error_message' => $e->getMessage(),
                'response_time_ms' => $responseTime,
            ]);

            return ['success' => false, 'error' => 'Request timed out'];

        } catch (RequestException $e) {
            $responseTime = (int)((microtime(true) - $startTime) * 1000);
            Log::error("OpenAI API error: {$e->getMessage()}");

            $this->logApiUsage([
                'provider' => 'openai',
                'service' => $model,
                'status' => 'error',
                'error_message' => $e->getMessage(),
                'response_time_ms' => $responseTime,
            ]);

            return ['success' => false, 'error' => $e->getMessage()];
        } catch (\Exception $e) {
            Log::error("OpenAI API error: {$e->getMessage()}");
            return ['success' => false, 'error' => $e->getMessage()];
        }
    }

    // ========================================
    // Anthropic Claude Integration
    // ========================================

    private function generateWithAnthropic(string $prompt, array $options = []): array
    {
        if (!$this->credentials?->anthropic_api_key) {
            return ['success' => false, 'error' => 'Anthropic not enabled or no API key configured'];
        }

        $startTime = microtime(true);
        $model = $options['model'] ?? 'claude-3-5-sonnet-20241022';
        $maxTokens = $options['max_tokens'] ?? $this->credentials->ai_max_tokens ?? 500;

        try {
            $body = [
                'model' => $model,
                'messages' => [
                    ['role' => 'user', 'content' => $prompt]
                ],
                'max_tokens' => $maxTokens,
                'temperature' => $options['temperature'] ?? 0.7
            ];

            $response = CircuitBreakerService::call('anthropic', function() use ($body) {
                return $this->client->post(self::ANTHROPIC_API_URL, [
                    'headers' => [
                        'x-api-key' => $this->credentials->anthropic_api_key,
                        'anthropic-version' => '2023-06-01',
                        'Content-Type' => 'application/json',
                    ],
                    'json' => $body,
                ]);
            });

            // Handle circuit breaker fallback
            if (is_array($response) && isset($response['circuit_open'])) {
                return ['success' => false, 'error' => $response['error']];
            }

            $responseTime = (int)((microtime(true) - $startTime) * 1000);

            if ($response->getStatusCode() == 200) {
                $data = json_decode($response->getBody()->getContents(), true);
                $text = $data['content'][0]['text'] ?? null;
                $usage = $data['usage'] ?? null;

                $this->logApiUsage([
                    'provider' => 'anthropic',
                    'service' => $model,
                    'status' => 'success',
                    'response_time_ms' => $responseTime,
                    'http_status_code' => 200,
                    'credits_used' => $usage['output_tokens'] ?? 0,
                    'response_data' => ['usage' => $usage],
                ]);

                return [
                    'success' => true,
                    'response' => $text,
                    'usage' => $usage,
                    'provider' => 'anthropic'
                ];
            }

            $errorData = json_decode($response->getBody()->getContents(), true);
            $errorMsg = $errorData['error']['message'] ?? 'Anthropic API error';

            $this->logApiUsage([
                'provider' => 'anthropic',
                'service' => $model,
                'status' => 'failed',
                'error_message' => $errorMsg,
                'response_time_ms' => $responseTime,
                'http_status_code' => $response->getStatusCode(),
            ]);

            return ['success' => false, 'error' => $errorMsg];

        } catch (ConnectException $e) {
            $responseTime = (int)((microtime(true) - $startTime) * 1000);
            Log::error("Anthropic API timeout: {$e->getMessage()}");

            $this->logApiUsage([
                'provider' => 'anthropic',
                'service' => $model,
                'status' => 'timeout',
                'error_message' => $e->getMessage(),
                'response_time_ms' => $responseTime,
            ]);

            return ['success' => false, 'error' => 'Request timed out'];

        } catch (RequestException $e) {
            $responseTime = (int)((microtime(true) - $startTime) * 1000);
            Log::error("Anthropic API error: {$e->getMessage()}");

            $this->logApiUsage([
                'provider' => 'anthropic',
                'service' => $model,
                'status' => 'error',
                'error_message' => $e->getMessage(),
                'response_time_ms' => $responseTime,
            ]);

            return ['success' => false, 'error' => $e->getMessage()];
        } catch (\Exception $e) {
            Log::error("Anthropic API error: {$e->getMessage()}");
            return ['success' => false, 'error' => $e->getMessage()];
        }
    }

    // ========================================
    // Google Gemini Integration
    // ========================================

    private function generateWithGoogleAi(string $prompt, array $options = []): array
    {
        if (!$this->credentials?->google_ai_api_key) {
            return ['success' => false, 'error' => 'Google AI not enabled or no API key configured'];
        }

        $startTime = microtime(true);
        $model = $options['model'] ?? 'gemini-1.5-flash';

        try {
            $url = self::GOOGLE_AI_API_URL . "/{$model}:generateContent?key=" . $this->credentials->google_ai_api_key;

            $body = [
                'contents' => [
                    [
                        'parts' => [
                            ['text' => $prompt]
                        ]
                    ]
                ],
                'generationConfig' => [
                    'temperature' => $options['temperature'] ?? 0.7,
                    'maxOutputTokens' => $options['max_tokens'] ?? $this->credentials->ai_max_tokens ?? 500,
                ]
            ];

            $response = CircuitBreakerService::call('google_ai', function() use ($url, $body) {
                return $this->client->post($url, [
                    'headers' => [
                        'Content-Type' => 'application/json',
                    ],
                    'json' => $body,
                ]);
            });

            // Handle circuit breaker fallback
            if (is_array($response) && isset($response['circuit_open'])) {
                return ['success' => false, 'error' => $response['error']];
            }

            $responseTime = (int)((microtime(true) - $startTime) * 1000);

            if ($response->getStatusCode() == 200) {
                $data = json_decode($response->getBody()->getContents(), true);
                $text = $data['candidates'][0]['content']['parts'][0]['text'] ?? null;
                $usage = $data['usageMetadata'] ?? null;

                $this->logApiUsage([
                    'provider' => 'google_ai',
                    'service' => $model,
                    'status' => 'success',
                    'response_time_ms' => $responseTime,
                    'http_status_code' => 200,
                    'credits_used' => $usage['totalTokenCount'] ?? 0,
                    'response_data' => ['usage' => $usage],
                ]);

                return [
                    'success' => true,
                    'response' => $text,
                    'usage' => $usage,
                    'provider' => 'google_ai'
                ];
            }

            $errorData = json_decode($response->getBody()->getContents(), true);
            $errorMsg = $errorData['error']['message'] ?? 'Google AI API error';

            $this->logApiUsage([
                'provider' => 'google_ai',
                'service' => $model,
                'status' => 'failed',
                'error_message' => $errorMsg,
                'response_time_ms' => $responseTime,
                'http_status_code' => $response->getStatusCode(),
            ]);

            return ['success' => false, 'error' => $errorMsg];

        } catch (ConnectException $e) {
            $responseTime = (int)((microtime(true) - $startTime) * 1000);
            Log::error("Google AI API timeout: {$e->getMessage()}");

            $this->logApiUsage([
                'provider' => 'google_ai',
                'service' => $model,
                'status' => 'timeout',
                'error_message' => $e->getMessage(),
                'response_time_ms' => $responseTime,
            ]);

            return ['success' => false, 'error' => 'Request timed out'];

        } catch (RequestException $e) {
            $responseTime = (int)((microtime(true) - $startTime) * 1000);
            Log::error("Google AI API error: {$e->getMessage()}");

            $this->logApiUsage([
                'provider' => 'google_ai',
                'service' => $model,
                'status' => 'error',
                'error_message' => $e->getMessage(),
                'response_time_ms' => $responseTime,
            ]);

            return ['success' => false, 'error' => $e->getMessage()];
        } catch (\Exception $e) {
            Log::error("Google AI API error: {$e->getMessage()}");
            return ['success' => false, 'error' => $e->getMessage()];
        }
    }

    // ========================================
    // OpenRouter Integration (OpenAI-compatible)
    // ========================================

    private function generateWithOpenrouter(string $prompt, array $options = []): array
    {
        if (!$this->credentials?->enable_openrouter) {
            return ['success' => false, 'error' => 'OpenRouter not enabled'];
        }

        if (empty($this->credentials->openrouter_api_key)) {
            return ['success' => false, 'error' => 'No OpenRouter API key configured'];
        }

        $startTime = microtime(true);
        $model = $options['model'] ?? $this->credentials->openrouter_model ?? 'openai/gpt-4o-mini';
        $maxTokens = $options['max_tokens'] ?? $this->credentials->ai_max_tokens ?? 500;

        try {
            $body = [
                'model' => $model,
                'messages' => [
                    ['role' => 'system', 'content' => 'You are a helpful assistant for a contact intelligence platform.'],
                    ['role' => 'user', 'content' => $prompt]
                ],
                'max_tokens' => $maxTokens,
                'temperature' => $options['temperature'] ?? 0.7
            ];

            $response = $this->client->post(self::OPENROUTER_API_URL, [
                'headers' => [
                    'Authorization' => 'Bearer ' . $this->credentials->openrouter_api_key,
                    'HTTP-Referer' => 'https://twilio-bulk-lookup.app',
                    'X-Title' => 'Twilio Bulk Lookup',
                    'Content-Type' => 'application/json',
                ],
                'json' => $body,
            ]);

            $responseTime = (int)((microtime(true) - $startTime) * 1000);

            if ($response->getStatusCode() == 200) {
                $data = json_decode($response->getBody()->getContents(), true);
                $text = $data['choices'][0]['message']['content'] ?? null;
                $usage = $data['usage'] ?? null;

                $this->logApiUsage([
                    'provider' => 'openrouter',
                    'service' => $model,
                    'status' => 'success',
                    'response_time_ms' => $responseTime,
                    'http_status_code' => 200,
                    'credits_used' => $usage['total_tokens'] ?? 0,
                    'response_data' => ['usage' => $usage],
                ]);

                return [
                    'success' => true,
                    'response' => $text,
                    'usage' => $usage,
                    'provider' => 'openrouter'
                ];
            }

            $errorData = json_decode($response->getBody()->getContents(), true);
            $errorMsg = $errorData['error']['message'] ?? 'OpenRouter API error';

            $this->logApiUsage([
                'provider' => 'openrouter',
                'service' => $model,
                'status' => 'failed',
                'error_message' => $errorMsg,
                'response_time_ms' => $responseTime,
                'http_status_code' => $response->getStatusCode(),
            ]);

            return ['success' => false, 'error' => $errorMsg];

        } catch (ConnectException $e) {
            $responseTime = (int)((microtime(true) - $startTime) * 1000);
            Log::error("OpenRouter API timeout: {$e->getMessage()}");

            $this->logApiUsage([
                'provider' => 'openrouter',
                'service' => $model,
                'status' => 'timeout',
                'error_message' => $e->getMessage(),
                'response_time_ms' => $responseTime,
            ]);

            return ['success' => false, 'error' => 'Request timed out'];

        } catch (RequestException $e) {
            $responseTime = (int)((microtime(true) - $startTime) * 1000);
            Log::error("OpenRouter API error: {$e->getMessage()}");

            $this->logApiUsage([
                'provider' => 'openrouter',
                'service' => $model,
                'status' => 'error',
                'error_message' => $e->getMessage(),
                'response_time_ms' => $responseTime,
            ]);

            return ['success' => false, 'error' => $e->getMessage()];
        } catch (\Exception $e) {
            Log::error("OpenRouter API error: {$e->getMessage()}");
            return ['success' => false, 'error' => $e->getMessage()];
        }
    }

    // ========================================
    // Prompt Building
    // ========================================

    private function buildQueryParsingPrompt(string $query): string
    {
        // Sanitize user input to prevent prompt injection
        $safeQuery = PromptSanitizer::sanitize($query, 500, 'search_query');

        return <<<PROMPT
Parse the following natural language query into contact search filters.
Return a JSON object with the appropriate filter criteria.

Query: "{$safeQuery}"

Available fields:
- line_type: mobile, landline, voip, toll_free
- sms_pumping_risk_level: low, medium, high
- is_business: true/false
- business_employee_range: 1-10, 11-50, 51-200, 201-500, 501-1000, 1001-5000, 5001-10000, 10000+
- business_state: US state codes
- email_verified: true/false
- phone_valid: true/false

Return only the JSON object, no explanation.
PROMPT;
    }

    private function buildSalesIntelligencePrompt($contact): string
    {
        // Sanitize contact fields to prevent prompt injection
        $safe = PromptSanitizer::sanitizeContact($contact);

        return <<<PROMPT
Analyze this contact for sales potential and provide insights:

Business: {$safe['business_name']}
Industry: {$safe['business_industry']}
Size: {$contact->business_employee_range}
Revenue: {$contact->business_revenue_range}
Location: {$safe['business_city']}, {$safe['business_state']}
Contact: {$safe['full_name']}
Title: {$safe['position']}

Provide:
1. Sales potential score (1-10)
2. Key selling points
3. Potential challenges
4. Recommended approach
PROMPT;
    }

    private function buildOutreachPrompt($contact, string $messageType): string
    {
        // Sanitize contact fields to prevent prompt injection
        $safe = PromptSanitizer::sanitizeContact($contact);

        switch ($messageType) {
            case 'intro':
                return <<<PROMPT
Write a brief, professional introduction SMS for:

Contact: {$safe['full_name']}
Title: {$safe['position']}
Company: {$safe['business_name']}
Industry: {$safe['business_industry']}

Keep it under 160 characters. Be concise and value-focused.
PROMPT;

            case 'follow_up':
                return <<<PROMPT
Write a brief follow-up SMS for:

Contact: {$safe['full_name']}
Company: {$safe['business_name']}

Previous contact was made. Keep it under 160 characters.
PROMPT;

            case 'email':
                return <<<PROMPT
Write a professional email introduction for:

Contact: {$safe['full_name']}
Title: {$safe['position']}
Company: {$safe['business_name']}
Industry: {$safe['business_industry']}

Keep it concise (2-3 paragraphs). Focus on value proposition.
PROMPT;

            default:
                return '';
        }
    }

    private function parseFilterResponse(string $response): array
    {
        try {
            $filters = json_decode($response, true);
            if (json_last_error() !== JSON_ERROR_NONE) {
                throw new \Exception(json_last_error_msg());
            }
            return ['success' => true, 'filters' => $filters];
        } catch (\Exception $e) {
            return [
                'success' => false,
                'error' => "Failed to parse filter response: {$e->getMessage()}",
                'raw_response' => $response
            ];
        }
    }

    private function logApiUsage(array $params): void
    {
        ApiUsageLog::logApiCall(array_merge($params, ['contact_id' => null]));
    }
}
