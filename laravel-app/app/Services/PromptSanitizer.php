<?php

namespace App\Services;

use Illuminate\Support\Facades\Log;

/**
 * PromptSanitizer
 *
 * Prevents AI prompt injection attacks by sanitizing user-controlled input
 * before interpolating into LLM prompts.
 *
 * Attack Vectors Mitigated:
 * - System prompt override attempts ("Ignore all previous instructions")
 * - Role confusion attacks ("SYSTEM:", "ASSISTANT:", "USER:")
 * - Newline-based prompt breaking (using \n to escape user context)
 * - Token manipulation (long inputs to exhaust max_tokens)
 * - Unicode tricks (invisible characters, right-to-left override)
 *
 * Usage:
 *   PromptSanitizer::sanitize($userInput, 500);
 *   PromptSanitizer::sanitizeHash($contactAttributes);
 */
class PromptSanitizer
{
    /**
     * Patterns that indicate prompt injection attempts
     */
    const INJECTION_PATTERNS = [
        '/ignore\s+(all\s+)?previous\s+instructions?/i',
        '/disregard\s+(all\s+)?previous\s+instructions?/i',
        '/forget\s+(all\s+)?previous\s+instructions?/i',
        '/\b(system|assistant|user)\s*:/i',
        '/\bprompt\s*:/i',
        '/\brole\s*:/i',
        '/\btemperature\s*[:=]/i',
        '/\bmax_tokens\s*[:=]/i',
        '/\bmodel\s*[:=]/i',
        '/<\|.*?\|>/',  // Special tokens used by some models
        '/\[INST\]/i',  // Instruction markers
        '/\[\/INST\]/i',
        '/<<SYS>>/i',
        '/<\/SYS>/i',
    ];

    /**
     * Unicode control characters and homoglyphs to strip
     */
    const DANGEROUS_UNICODE = [
        "\u{200B}",  // Zero-width space
        "\u{200C}",  // Zero-width non-joiner
        "\u{200D}",  // Zero-width joiner
        "\u{200E}",  // Left-to-right mark
        "\u{200F}",  // Right-to-left mark
        "\u{202A}",  // Left-to-right embedding
        "\u{202B}",  // Right-to-left embedding
        "\u{202C}",  // Pop directional formatting
        "\u{202D}",  // Left-to-right override
        "\u{202E}",  // Right-to-left override
        "\u{FEFF}",  // Zero-width no-break space
    ];

    /**
     * Sanitize a single string input
     *
     * @param string|null $input User-controlled input
     * @param int $maxLength Maximum allowed length
     * @param string $fieldName Field name for logging
     * @return string Sanitized string safe for prompt interpolation
     */
    public static function sanitize(?string $input, int $maxLength = 1000, string $fieldName = 'input'): string
    {
        if (empty($input)) {
            return '';
        }

        $sanitized = $input;

        // Step 1: Remove dangerous Unicode characters
        foreach (self::DANGEROUS_UNICODE as $char) {
            $sanitized = str_replace($char, '', $sanitized);
        }

        // Step 2: Normalize whitespace (prevent newline-based escapes)
        // Replace multiple spaces/newlines with single space
        $sanitized = preg_replace('/\s+/', ' ', $sanitized);

        // Step 3: Detect and log injection attempts
        foreach (self::INJECTION_PATTERNS as $pattern) {
            if (preg_match($pattern, $sanitized)) {
                Log::warning(
                    "Potential prompt injection detected in {$fieldName}: " .
                    substr($sanitized, 0, 100) . " (pattern: {$pattern})"
                );

                // Strip the matching pattern
                $sanitized = preg_replace($pattern, '[REDACTED]', $sanitized);
            }
        }

        // Step 4: Truncate to max length
        if (mb_strlen($sanitized) > $maxLength) {
            Log::info(
                "Truncating {$fieldName} from " . mb_strlen($sanitized) . " to {$maxLength} characters"
            );
            $sanitized = mb_substr($sanitized, 0, $maxLength) . '...';
        }

        // Step 5: Strip leading/trailing whitespace
        return trim($sanitized);
    }

    /**
     * Sanitize all string values in a hash
     *
     * @param array $data Hash with potentially unsafe values
     * @param array $config Field-specific max_length overrides
     * @return array Hash with sanitized values
     */
    public static function sanitizeHash(array $data, array $config = []): array
    {
        $result = [];

        foreach ($data as $key => $value) {
            $maxLength = $config[$key]['max_length'] ?? 1000;
            $fieldName = (string) $key;

            if (is_string($value)) {
                $result[$key] = self::sanitize($value, $maxLength, $fieldName);
            } else {
                $result[$key] = $value;
            }
        }

        return $result;
    }

    /**
     * Sanitize contact profile fields for AI prompts
     *
     * @param object $contact Contact model instance
     * @return array Sanitized contact attributes
     */
    public static function sanitizeContact($contact): array
    {
        return [
            'phone' => self::sanitize($contact->formatted_phone_number ?? $contact->raw_phone_number ?? '', 20),
            'full_name' => self::sanitize($contact->full_name ?? '', 100),
            'email' => self::sanitize($contact->email ?? '', 255),
            'business_name' => self::sanitize($contact->business_name ?? '', 200),
            'business_industry' => self::sanitize($contact->business_industry ?? '', 100),
            'business_description' => self::sanitize($contact->business_description ?? '', 500),
            'business_city' => self::sanitize($contact->business_city ?? '', 100),
            'business_state' => self::sanitize($contact->business_state ?? '', 50),
            'business_website' => self::sanitize($contact->business_website ?? '', 255),
            'position' => self::sanitize($contact->position ?? '', 100),
            'department' => self::sanitize($contact->department ?? '', 100),
        ];
    }
}
