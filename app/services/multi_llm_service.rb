require 'net/http'
require 'json'

class MultiLlmService
  OPENAI_API_URL = 'https://api.openai.com/v1/chat/completions'
  ANTHROPIC_API_URL = 'https://api.anthropic.com/v1/messages'
  GOOGLE_AI_API_URL = 'https://generativelanguage.googleapis.com/v1beta/models'

  def initialize
    @credentials = TwilioCredential.current
  end

  # Generate text using the preferred LLM provider
  def generate(prompt, options = {})
    provider = options[:provider] || @credentials&.preferred_llm_provider || 'openai'

    case provider
    when 'openai'
      generate_with_openai(prompt, options)
    when 'anthropic'
      generate_with_anthropic(prompt, options)
    when 'google'
      generate_with_google_ai(prompt, options)
    else
      { success: false, error: "Unknown LLM provider: #{provider}" }
    end
  end

  # Parse natural language query to search filters (existing functionality)
  def parse_query(query, options = {})
    prompt = build_query_parsing_prompt(query)
    result = generate(prompt, options.merge(max_tokens: 500))

    if result[:success]
      parse_filter_response(result[:response])
    else
      result
    end
  end

  # Generate sales intelligence
  def generate_sales_intelligence(contact, options = {})
    prompt = build_sales_intelligence_prompt(contact)
    generate(prompt, options.merge(max_tokens: 800))
  end

  # Generate outreach message
  def generate_outreach_message(contact, message_type: 'intro', options: {})
    prompt = build_outreach_prompt(contact, message_type)
    generate(prompt, options.merge(max_tokens: 300))
  end

  private

  # ========================================
  # OpenAI Integration
  # ========================================

  def generate_with_openai(prompt, options = {})
    return { success: false, error: 'OpenAI not enabled' } unless @credentials&.enable_ai_features
    return { success: false, error: 'No OpenAI API key configured' } unless @credentials.openai_api_key.present?

    start_time = Time.current
    model = options[:model] || @credentials.ai_model || 'gpt-4o-mini'
    max_tokens = options[:max_tokens] || @credentials.ai_max_tokens || 500

    begin
      uri = URI(OPENAI_API_URL)
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request['Authorization'] = "Bearer #{@credentials.openai_api_key}"

      request.body = {
        model: model,
        messages: [
          { role: 'system', content: 'You are a helpful assistant for a contact intelligence platform.' },
          { role: 'user', content: prompt }
        ],
        max_tokens: max_tokens,
        temperature: options[:temperature] || 0.7
      }.to_json

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 30) do |http|
        http.request(request)
      end

      if response.code.to_i == 200
        data = JSON.parse(response.body)
        text = data.dig('choices', 0, 'message', 'content')
        usage = data['usage']

        # Log API usage with cost
        log_api_usage(
          provider: 'openai',
          service: model,
          status: 'success',
          response_time_ms: ((Time.current - start_time) * 1000).to_i,
          http_status_code: 200,
          credits_used: usage['total_tokens'],
          response_data: { usage: usage }
        )

        { success: true, response: text, usage: usage, provider: 'openai' }
      else
        error_data = JSON.parse(response.body) rescue {}
        error_msg = error_data.dig('error', 'message') || 'OpenAI API error'

        log_api_usage(
          provider: 'openai',
          service: model,
          status: 'failed',
          error_message: error_msg,
          response_time_ms: ((Time.current - start_time) * 1000).to_i,
          http_status_code: response.code.to_i
        )

        { success: false, error: error_msg }
      end
    rescue => e
      Rails.logger.error "OpenAI API error: #{e.message}"

      log_api_usage(
        provider: 'openai',
        service: model,
        status: 'error',
        error_message: e.message,
        response_time_ms: ((Time.current - start_time) * 1000).to_i
      )

      { success: false, error: e.message }
    end
  end

  # ========================================
  # Anthropic Claude Integration
  # ========================================

  def generate_with_anthropic(prompt, options = {})
    return { success: false, error: 'Anthropic not enabled' } unless @credentials&.enable_anthropic
    return { success: false, error: 'No Anthropic API key configured' } unless @credentials.anthropic_api_key.present?

    start_time = Time.current
    model = options[:model] || @credentials.anthropic_model || 'claude-3-5-sonnet-20241022'
    max_tokens = options[:max_tokens] || @credentials.ai_max_tokens || 500

    begin
      uri = URI(ANTHROPIC_API_URL)
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request['x-api-key'] = @credentials.anthropic_api_key
      request['anthropic-version'] = '2023-06-01'

      request.body = {
        model: model,
        messages: [
          { role: 'user', content: prompt }
        ],
        max_tokens: max_tokens,
        temperature: options[:temperature] || 0.7
      }.to_json

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 30) do |http|
        http.request(request)
      end

      if response.code.to_i == 200
        data = JSON.parse(response.body)
        text = data.dig('content', 0, 'text')
        usage = data['usage']

        log_api_usage(
          provider: 'anthropic',
          service: model,
          status: 'success',
          response_time_ms: ((Time.current - start_time) * 1000).to_i,
          http_status_code: 200,
          credits_used: usage['output_tokens'],
          response_data: { usage: usage }
        )

        { success: true, response: text, usage: usage, provider: 'anthropic' }
      else
        error_data = JSON.parse(response.body) rescue {}
        error_msg = error_data.dig('error', 'message') || 'Anthropic API error'

        log_api_usage(
          provider: 'anthropic',
          service: model,
          status: 'failed',
          error_message: error_msg,
          response_time_ms: ((Time.current - start_time) * 1000).to_i,
          http_status_code: response.code.to_i
        )

        { success: false, error: error_msg }
      end
    rescue => e
      Rails.logger.error "Anthropic API error: #{e.message}"

      log_api_usage(
        provider: 'anthropic',
        service: model,
        status: 'error',
        error_message: e.message,
        response_time_ms: ((Time.current - start_time) * 1000).to_i
      )

      { success: false, error: e.message }
    end
  end

  # ========================================
  # Google Gemini Integration
  # ========================================

  def generate_with_google_ai(prompt, options = {})
    return { success: false, error: 'Google AI not enabled' } unless @credentials&.enable_google_ai
    return { success: false, error: 'No Google AI API key configured' } unless @credentials.google_ai_api_key.present?

    start_time = Time.current
    model = options[:model] || @credentials.google_ai_model || 'gemini-1.5-flash'

    begin
      uri = URI("#{GOOGLE_AI_API_URL}/#{model}:generateContent?key=#{@credentials.google_ai_api_key}")
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'

      request.body = {
        contents: [
          {
            parts: [
              { text: prompt }
            ]
          }
        ],
        generationConfig: {
          temperature: options[:temperature] || 0.7,
          maxOutputTokens: options[:max_tokens] || @credentials.ai_max_tokens || 500
        }
      }.to_json

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 30) do |http|
        http.request(request)
      end

      if response.code.to_i == 200
        data = JSON.parse(response.body)
        text = data.dig('candidates', 0, 'content', 'parts', 0, 'text')
        usage = data['usageMetadata']

        log_api_usage(
          provider: 'google_ai',
          service: model,
          status: 'success',
          response_time_ms: ((Time.current - start_time) * 1000).to_i,
          http_status_code: 200,
          credits_used: usage&.[]('totalTokenCount') || 0,
          response_data: { usage: usage }
        )

        { success: true, response: text, usage: usage, provider: 'google_ai' }
      else
        error_data = JSON.parse(response.body) rescue {}
        error_msg = error_data.dig('error', 'message') || 'Google AI API error'

        log_api_usage(
          provider: 'google_ai',
          service: model,
          status: 'failed',
          error_message: error_msg,
          response_time_ms: ((Time.current - start_time) * 1000).to_i,
          http_status_code: response.code.to_i
        )

        { success: false, error: error_msg }
      end
    rescue => e
      Rails.logger.error "Google AI API error: #{e.message}"

      log_api_usage(
        provider: 'google_ai',
        service: model,
        status: 'error',
        error_message: e.message,
        response_time_ms: ((Time.current - start_time) * 1000).to_i
      )

      { success: false, error: e.message }
    end
  end

  # ========================================
  # Prompt Building
  # ========================================

  def build_query_parsing_prompt(query)
    <<~PROMPT
      Parse the following natural language query into contact search filters.
      Return a JSON object with the appropriate filter criteria.

      Query: "#{query}"

      Available fields:
      - line_type: mobile, landline, voip, toll_free
      - sms_pumping_risk_level: low, medium, high
      - is_business: true/false
      - business_employee_range: 1-10, 11-50, 51-200, 201-500, 501-1000, 1001-5000, 5001-10000, 10000+
      - business_state: US state codes
      - email_verified: true/false
      - valid: true/false

      Return only the JSON object, no explanation.
    PROMPT
  end

  def build_sales_intelligence_prompt(contact)
    <<~PROMPT
      Analyze this contact for sales potential and provide insights:

      Business: #{contact.business_name || 'Unknown'}
      Industry: #{contact.business_industry || 'Unknown'}
      Size: #{contact.business_employee_range || 'Unknown'}
      Revenue: #{contact.business_revenue_range || 'Unknown'}
      Location: #{contact.business_city}, #{contact.business_state}
      Contact: #{contact.full_name || 'Unknown'}
      Title: #{contact.position || 'Unknown'}

      Provide:
      1. Sales potential score (1-10)
      2. Key selling points
      3. Potential challenges
      4. Recommended approach
    PROMPT
  end

  def build_outreach_prompt(contact, message_type)
    case message_type
    when 'intro'
      <<~PROMPT
        Write a brief, professional introduction SMS for:

        Contact: #{contact.full_name || contact.business_name}
        Title: #{contact.position}
        Company: #{contact.business_name}
        Industry: #{contact.business_industry}

        Keep it under 160 characters. Be concise and value-focused.
      PROMPT
    when 'follow_up'
      <<~PROMPT
        Write a brief follow-up SMS for:

        Contact: #{contact.full_name || contact.business_name}
        Company: #{contact.business_name}

        Previous contact was made. Keep it under 160 characters.
      PROMPT
    when 'email'
      <<~PROMPT
        Write a professional email introduction for:

        Contact: #{contact.full_name}
        Title: #{contact.position}
        Company: #{contact.business_name}
        Industry: #{contact.business_industry}

        Keep it concise (2-3 paragraphs). Focus on value proposition.
      PROMPT
    end
  end

  def parse_filter_response(response)
    begin
      filters = JSON.parse(response)
      { success: true, filters: filters }
    rescue JSON::ParserError => e
      { success: false, error: "Failed to parse filter response: #{e.message}", raw_response: response }
    end
  end

  def log_api_usage(params)
    ApiUsageLog.log_api_call(params.merge(contact_id: nil))
  end
end
