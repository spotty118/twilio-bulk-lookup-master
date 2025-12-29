<?php

namespace App\Services;

use App\Models\TwilioCredential;
use Illuminate\Support\Facades\Log;

/**
 * AiAssistantService - Natural language AI assistant for contact intelligence
 *
 * Features:
 * - Natural language query processing
 * - Contact data analysis and insights
 * - Sales intelligence generation
 * - Automated outreach message generation
 * - Integration with MultiLlmService for provider flexibility
 *
 * Usage:
 *   AiAssistantService::query("Find all mobile contacts in California")
 *   AiAssistantService::generateSalesIntelligence($contact)
 *   AiAssistantService::naturalLanguageSearch("tech companies with 50+ employees")
 */
class AiAssistantService
{
    private $llmService;
    private $credentials;

    public function __construct()
    {
        $this->llmService = new MultiLlmService();
        $this->credentials = TwilioCredential::current();
    }

    /**
     * Main AI assistant for natural language queries
     *
     * @param string $prompt User's question or request
     * @param string|null $context Optional context to provide to the AI
     * @return string|array AI response or error
     */
    public static function query(string $prompt, ?string $context = null)
    {
        return (new static())->processQuery($prompt, $context);
    }

    /**
     * Generate sales intelligence for a contact
     *
     * @param object $contact Contact model instance
     * @return string|array Sales intelligence or error
     */
    public static function generateSalesIntelligence($contact)
    {
        return (new static())->processSalesIntelligence($contact);
    }

    /**
     * Natural language search - convert user query to structured filters
     *
     * @param string $query Natural language search query
     * @return array Search filters or error
     */
    public static function naturalLanguageSearch(string $query): array
    {
        return (new static())->processNaturalLanguageSearch($query);
    }

    /**
     * Generate outreach message for a contact
     *
     * @param object $contact Contact model instance
     * @param string $templateType Type of message: intro, follow_up, email
     * @return string|array Outreach message or error
     */
    public static function generateOutreach($contact, string $templateType = 'intro')
    {
        return (new static())->processOutreach($contact, $templateType);
    }

    /**
     * Process general AI query
     */
    private function processQuery(string $prompt, ?string $context = null)
    {
        if (!$this->aiEnabled()) {
            return ['error' => 'AI features not enabled'];
        }

        $messages = [
            [
                'role' => 'system',
                'content' => 'You are a helpful AI assistant for a sales CRM focused on phone number intelligence and business data. Provide concise, actionable insights.'
            ]
        ];

        if ($context) {
            $messages[] = [
                'role' => 'system',
                'content' => "Context: {$context}"
            ];
        }

        // Combine messages into a single prompt for the LLM service
        $fullPrompt = $prompt;
        if ($context) {
            $fullPrompt = "Context: {$context}\n\n{$prompt}";
        }

        $response = $this->llmService->generate($fullPrompt);

        if ($response['success']) {
            return $response['response'];
        }

        return $response;
    }

    /**
     * Process sales intelligence generation
     */
    private function processSalesIntelligence($contact)
    {
        if (!$this->aiEnabled()) {
            return ['error' => 'AI features not enabled'];
        }

        // Build comprehensive contact profile
        $profile = $this->buildContactProfile($contact);

        $prompt = <<<PROMPT
Analyze this sales contact and provide actionable intelligence:

{$profile}

Provide:
1. Key insights about this contact (2-3 bullet points)
2. Potential pain points or needs based on their business
3. Recommended talking points for sales outreach
4. Best time/channel to reach them (based on contact type)
5. Risk assessment (fraud risk, data quality issues)

Keep response concise and sales-focused.
PROMPT;

        $response = $this->llmService->generate($prompt);

        if ($response['success']) {
            return $response['response'];
        }

        return $response;
    }

    /**
     * Process natural language search
     */
    private function processNaturalLanguageSearch(string $searchQuery): array
    {
        if (!$this->aiEnabled()) {
            return ['error' => 'AI features not enabled'];
        }

        // Sanitize user input to prevent prompt injection
        $safeQuery = PromptSanitizer::sanitize($searchQuery, 500, 'search_query');

        // Use LLM to convert natural language to structured query
        $prompt = <<<PROMPT
Convert this natural language query into structured search criteria for a contact database:

Query: "{$safeQuery}"

Available fields:
- business_name, business_industry, business_type
- business_employee_range (1-10, 11-50, 51-200, 201-500, 501-1000, 1001-5000, 5001-10000, 10000+)
- business_revenue_range (\$0-\$1M, \$1M-\$10M, \$10M-\$50M, \$50M-\$100M, \$100M-\$500M, \$500M-\$1B, \$1B+)
- business_city, business_state, business_country
- line_type (mobile, landline, voip)
- sms_pumping_risk_level (low, medium, high)
- is_business (true/false)
- email_verified (true/false)
- status (pending, processing, completed, failed)

Respond ONLY with JSON in this format:
{
  "filters": {
    "field_name": "value",
    "another_field": "value"
  },
  "explanation": "Plain English explanation of what will be searched"
}
PROMPT;

        $response = $this->llmService->generate($prompt);

        if (!$response['success']) {
            return $response;
        }

        if (!is_string($response['response'])) {
            return ['error' => 'AI parsing failed'];
        }

        try {
            // Extract JSON from response
            $jsonMatch = $this->extractFirstJsonObject($response['response']);
            if (!$jsonMatch) {
                return ['error' => 'No JSON found in response'];
            }

            $parsed = json_decode($jsonMatch, true);
            if (json_last_error() !== JSON_ERROR_NONE) {
                throw new \Exception(json_last_error_msg());
            }

            return [
                'filters' => $parsed['filters'] ?? [],
                'explanation' => $parsed['explanation'] ?? '',
                'raw_response' => $response['response']
            ];
        } catch (\Exception $e) {
            return [
                'error' => "Failed to parse AI response: {$e->getMessage()}",
                'raw' => $response['response']
            ];
        }
    }

    /**
     * Process outreach message generation
     */
    private function processOutreach($contact, string $templateType = 'intro')
    {
        if (!$this->aiEnabled()) {
            return ['error' => 'AI features not enabled'];
        }

        $profile = $this->buildContactProfile($contact);

        $prompt = match ($templateType) {
            'intro' => <<<PROMPT
Write a personalized cold outreach message for this contact:

{$profile}

Requirements:
- Professional but friendly tone
- Reference their business/industry specifically
- Keep under 100 words
- Include a clear call-to-action
- Don't be pushy or salesy

Format: SMS-friendly (no special formatting)
PROMPT,

            'follow_up' => <<<PROMPT
Write a follow-up message for this contact (assume they didn't respond to initial outreach):

{$profile}

Requirements:
- Brief reminder of previous message
- Add new value/angle
- Soft call-to-action
- Under 80 words
- SMS-friendly format
PROMPT,

            'email' => <<<PROMPT
Write a professional email to this contact:

{$profile}

Requirements:
- Include subject line
- Professional email format
- Personalized based on their business
- Clear value proposition
- Strong call-to-action
- Keep under 150 words
PROMPT,

            default => ''
        };

        if (empty($prompt)) {
            return ['error' => 'Invalid template type'];
        }

        $response = $this->llmService->generate($prompt);

        if ($response['success']) {
            return $response['response'];
        }

        return $response;
    }

    /**
     * Check if AI features are enabled
     */
    private function aiEnabled(): bool
    {
        if (!$this->credentials?->enable_ai_features) {
            return false;
        }

        // Check if at least one LLM provider is configured
        $hasProvider = !empty($this->credentials->openai_api_key)
            || !empty($this->credentials->anthropic_api_key)
            || !empty($this->credentials->google_ai_api_key)
            || ($this->credentials->enable_openrouter && !empty($this->credentials->openrouter_api_key));

        return $hasProvider;
    }

    /**
     * Extract first complete JSON object from text using balanced brace counting
     * This is more reliable than greedy regex
     */
    private function extractFirstJsonObject(string $text): ?string
    {
        $startIdx = strpos($text, '{');
        if ($startIdx === false) {
            return null;
        }

        $depth = 0;
        $inString = false;
        $escapeNext = false;
        $length = strlen($text);

        for ($i = $startIdx; $i < $length; $i++) {
            $char = $text[$i];

            if ($escapeNext) {
                $escapeNext = false;
                continue;
            }

            if ($char === '\\' && $inString) {
                $escapeNext = true;
                continue;
            }

            if ($char === '"') {
                $inString = !$inString;
                continue;
            }

            if (!$inString) {
                if ($char === '{') {
                    $depth++;
                } elseif ($char === '}') {
                    $depth--;
                    if ($depth === 0) {
                        return substr($text, $startIdx, $i - $startIdx + 1);
                    }
                }
            }
        }

        return null; // No complete JSON object found
    }

    /**
     * Build comprehensive contact profile for AI prompts
     */
    private function buildContactProfile($contact): string
    {
        // Sanitize all user-controlled fields to prevent prompt injection
        $safe = PromptSanitizer::sanitizeContact($contact);

        $profile = [];

        // Basic info
        $profile[] = "Phone: {$safe['phone']}";
        if (!empty($safe['full_name'])) {
            $profile[] = "Name: {$safe['full_name']}";
        }
        if (!empty($safe['email'])) {
            $profile[] = "Email: {$safe['email']}";
        }

        // Contact type
        if ($contact->is_business ?? false) {
            $profile[] = "\nBusiness Contact:";
            if (!empty($safe['business_name'])) {
                $profile[] = "- Company: {$safe['business_name']}";
            }
            if (!empty($safe['business_industry'])) {
                $profile[] = "- Industry: {$safe['business_industry']}";
            }
            if (!empty($contact->business_employee_range)) {
                $profile[] = "- Size: {$contact->business_employee_range}";
            }
            if (!empty($contact->business_revenue_range)) {
                $profile[] = "- Revenue: {$contact->business_revenue_range}";
            }
            if (!empty($safe['business_city'])) {
                $profile[] = "- Location: {$safe['business_city']}, {$safe['business_state']}";
            }
            if (!empty($safe['business_website'])) {
                $profile[] = "- Website: {$safe['business_website']}";
            }
            if (!empty($safe['business_description'])) {
                $profile[] = "- Description: {$safe['business_description']}";
            }
        } else {
            $profile[] = "\nConsumer Contact";
        }

        // Contact quality/risk
        $profile[] = "\nData Quality:";
        $profile[] = "- Phone Valid: " . ($contact->phone_valid ? 'Yes' : 'Unknown');
        if (!empty($contact->line_type)) {
            $profile[] = "- Line Type: {$contact->line_type}";
        }
        if (!empty($contact->sms_pumping_risk_level)) {
            $profile[] = "- Fraud Risk: {$contact->sms_pumping_risk_level}";
        }

        if ($contact->email_verified ?? false) {
            $profile[] = "- Email: Verified";
        } elseif (!empty($contact->email)) {
            $profile[] = "- Email: Unverified";
        }

        // Position/role
        if (!empty($safe['position'])) {
            $profile[] = "- Position: {$safe['position']}";
        }
        if (!empty($safe['department'])) {
            $profile[] = "- Department: {$safe['department']}";
        }

        return implode("\n", $profile);
    }
}
