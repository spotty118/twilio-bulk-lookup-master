require 'net/http'
require 'json'

class AiAssistantService
  # Main AI assistant for natural language queries
  def self.query(prompt, context: nil)
    new.query(prompt, context: context)
  end

  # Generate sales intelligence for a contact
  def self.generate_sales_intelligence(contact)
    new.generate_sales_intelligence(contact)
  end

  # Natural language search
  def self.natural_language_search(query)
    new.natural_language_search(query)
  end

  # Generate outreach message
  def self.generate_outreach(contact, template_type: 'intro')
    new.generate_outreach(contact, template_type: template_type)
  end

  def initialize
    @api_key = ENV['OPENAI_API_KEY'] || TwilioCredential.current&.openai_api_key
    @model = TwilioCredential.current&.ai_model || 'gpt-4o-mini'
    @max_tokens = TwilioCredential.current&.ai_max_tokens || 500
  end

  def query(prompt, context: nil)
    return { error: "AI features not enabled" } unless ai_enabled?

    messages = [
      {
        role: "system",
        content: "You are a helpful AI assistant for a sales CRM focused on phone number intelligence and business data. Provide concise, actionable insights."
      }
    ]

    if context
      messages << {
        role: "system",
        content: "Context: #{context}"
      }
    end

    messages << {
      role: "user",
      content: prompt
    }

    response = call_openai(messages)
    response[:content] if response
  end

  def generate_sales_intelligence(contact)
    return { error: "AI features not enabled" } unless ai_enabled?

    # Build comprehensive contact profile
    profile = build_contact_profile(contact)

    prompt = <<~PROMPT
      Analyze this sales contact and provide actionable intelligence:

      #{profile}

      Provide:
      1. Key insights about this contact (2-3 bullet points)
      2. Potential pain points or needs based on their business
      3. Recommended talking points for sales outreach
      4. Best time/channel to reach them (based on contact type)
      5. Risk assessment (fraud risk, data quality issues)

      Keep response concise and sales-focused.
    PROMPT

    query(prompt)
  end

  def natural_language_search(search_query)
    return { error: "AI features not enabled" } unless ai_enabled?

    # Sanitize user input to prevent prompt injection
    safe_query = PromptSanitizer.sanitize(search_query, max_length: 500, field_name: 'search_query')

    # Use GPT to convert natural language to SQL-like query
    prompt = <<~PROMPT
      Convert this natural language query into structured search criteria for a contact database:

      Query: "#{safe_query}"

      Available fields:
      - business_name, business_industry, business_type
      - business_employee_range (1-10, 11-50, 51-200, 201-500, 501-1000, 1001-5000, 5001-10000, 10000+)
      - business_revenue_range ($0-$1M, $1M-$10M, $10M-$50M, $50M-$100M, $100M-$500M, $500M-$1B, $1B+)
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
    PROMPT

    response = query(prompt)
    return { error: "AI parsing failed" } unless response

    begin
      # Extract JSON from response
      json_match = response.match(/\{.*\}/m)
      return { error: "No JSON found in response" } unless json_match

      parsed = JSON.parse(json_match[0])
      {
        filters: parsed['filters'],
        explanation: parsed['explanation'],
        raw_response: response
      }
    rescue JSON::ParserError => e
      { error: "Failed to parse AI response: #{e.message}", raw: response }
    end
  end

  def generate_outreach(contact, template_type: 'intro')
    return { error: "AI features not enabled" } unless ai_enabled?

    profile = build_contact_profile(contact)

    prompt = case template_type
    when 'intro'
      <<~PROMPT
        Write a personalized cold outreach message for this contact:

        #{profile}

        Requirements:
        - Professional but friendly tone
        - Reference their business/industry specifically
        - Keep under 100 words
        - Include a clear call-to-action
        - Don't be pushy or salesy

        Format: SMS-friendly (no special formatting)
      PROMPT
    when 'follow_up'
      <<~PROMPT
        Write a follow-up message for this contact (assume they didn't respond to initial outreach):

        #{profile}

        Requirements:
        - Brief reminder of previous message
        - Add new value/angle
        - Soft call-to-action
        - Under 80 words
        - SMS-friendly format
      PROMPT
    when 'email'
      <<~PROMPT
        Write a professional email to this contact:

        #{profile}

        Requirements:
        - Include subject line
        - Professional email format
        - Personalized based on their business
        - Clear value proposition
        - Strong call-to-action
        - Keep under 150 words
      PROMPT
    end

    query(prompt)
  end

  private

  def ai_enabled?
    credentials = TwilioCredential.current
    return false unless credentials&.enable_ai_features
    return false unless @api_key.present?
    true
  end

  def call_openai(messages)
    uri = URI('https://api.openai.com/v1/chat/completions')

    body = {
      model: @model,
      messages: messages,
      max_tokens: @max_tokens,
      temperature: 0.7
    }

    # AI generation requires longer timeout (30s vs 10s default)
    response = HttpClient.post(uri,
                               body: body,
                               circuit_name: 'openai-api',
                               read_timeout: 30,
                               open_timeout: 10,
                               connect_timeout: 10) do |request|
      request['Authorization'] = "Bearer #{@api_key}"
    end

    return nil unless response.code == '200'

    data = JSON.parse(response.body)
    {
      content: data.dig('choices', 0, 'message', 'content'),
      usage: data['usage']
    }
  rescue HttpClient::TimeoutError => e
    Rails.logger.error("OpenAI API timeout: #{e.message}")
    nil
  rescue HttpClient::CircuitOpenError => e
    Rails.logger.error("OpenAI circuit open: #{e.message}")
    nil
  rescue JSON::ParserError => e
    Rails.logger.error("OpenAI API invalid JSON: #{e.message}")
    nil
  rescue StandardError => e
    Rails.logger.error("OpenAI API error: #{e.message}")
    nil
  end

  def build_contact_profile(contact)
    # Sanitize all user-controlled fields to prevent prompt injection
    safe = PromptSanitizer.sanitize_contact(contact)

    profile = []

    # Basic info
    profile << "Phone: #{safe[:phone]}"
    profile << "Name: #{safe[:full_name]}" if safe[:full_name].present?
    profile << "Email: #{safe[:email]}" if safe[:email].present?

    # Contact type
    if contact.business?
      profile << "\nBusiness Contact:"
      profile << "- Company: #{safe[:business_name]}" if safe[:business_name].present?
      profile << "- Industry: #{safe[:business_industry]}" if safe[:business_industry].present?
      profile << "- Size: #{contact.business_size_category}" if contact.business_employee_range.present?
      profile << "- Revenue: #{contact.business_revenue_range}" if contact.business_revenue_range.present?
      profile << "- Location: #{safe[:business_city]}, #{safe[:business_state]}" if safe[:business_city].present?
      profile << "- Website: #{safe[:business_website]}" if safe[:business_website].present?
      profile << "- Description: #{safe[:business_description]}" if safe[:business_description].present?
    else
      profile << "\nConsumer Contact"
    end

    # Contact quality/risk
    profile << "\nData Quality:"
    profile << "- Phone Valid: #{contact.phone_valid ? 'Yes' : 'Unknown'}"
    profile << "- Line Type: #{contact.line_type_display}" if contact.line_type.present?
    profile << "- Fraud Risk: #{contact.fraud_risk_display}" if contact.sms_pumping_risk_level.present?

    if contact.email_verified
      profile << "- Email: Verified"
    elsif contact.email.present?
      profile << "- Email: Unverified"
    end

    # Position/role
    profile << "- Position: #{safe[:position]}" if safe[:position].present?
    profile << "- Department: #{safe[:department]}" if safe[:department].present?

    profile.join("\n")
  end
end
