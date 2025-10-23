class AiAssistantService
  # Main AI assistant for natural language queries
  # Now supports multiple LLM providers: OpenAI, Anthropic Claude, Google Gemini, and OpenRouter

  def self.query(prompt, context: nil, provider: nil)
    new.query(prompt, context: context, provider: provider)
  end

  def self.generate_sales_intelligence(contact, provider: nil)
    new.generate_sales_intelligence(contact, provider: provider)
  end

  def self.natural_language_search(search_query, provider: nil)
    new.natural_language_search(search_query, provider: provider)
  end

  def self.generate_outreach(contact, template_type: 'intro', provider: nil)
    new.generate_outreach(contact, template_type: template_type, provider: provider)
  end

  def initialize
    @credentials = TwilioCredential.current
    @llm_service = MultiLlmService.new
  end

  def query(prompt, context: nil, provider: nil)
    return { error: "AI features not enabled" } unless ai_enabled?

    system_prompt = "You are a helpful AI assistant for a sales CRM focused on phone number intelligence and business data. Provide concise, actionable insights."

    if context
      system_prompt += "\n\nContext: #{context}"
    end

    full_prompt = "#{system_prompt}\n\n#{prompt}"

    result = @llm_service.generate(full_prompt, provider: provider || preferred_provider)

    if result[:success]
      {
        content: result[:response],
        provider: result[:provider],
        usage: result[:usage]
      }
    else
      { error: result[:error] }
    end
  end

  def generate_sales_intelligence(contact, provider: nil)
    return { error: "AI features not enabled" } unless ai_enabled?

    # Use the new MultiLlmService method
    result = @llm_service.generate_sales_intelligence(contact, provider: provider || preferred_provider)

    if result[:success]
      {
        content: result[:response],
        provider: result[:provider],
        usage: result[:usage]
      }
    else
      { error: result[:error] }
    end
  end

  def natural_language_search(search_query, provider: nil)
    return { error: "AI features not enabled" } unless ai_enabled?

    # Use the new MultiLlmService method
    result = @llm_service.parse_query(search_query, provider: provider || preferred_provider)

    if result[:success]
      result
    else
      { error: result[:error] }
    end
  end

  def generate_outreach(contact, template_type: 'intro', provider: nil)
    return { error: "AI features not enabled" } unless ai_enabled?

    # Use the new MultiLlmService method
    result = @llm_service.generate_outreach_message(
      contact,
      message_type: template_type,
      provider: provider || preferred_provider
    )

    if result[:success]
      {
        content: result[:response],
        provider: result[:provider],
        usage: result[:usage]
      }
    else
      { error: result[:error] }
    end
  end

  # Data analysis and insights
  def analyze_contact_quality(limit: 100)
    return { error: "AI features not enabled" } unless ai_enabled?

    # Get sample of contacts with quality issues
    low_quality = Contact.low_quality.limit(limit)

    summary = {
      total: Contact.count,
      low_quality_count: Contact.low_quality.count,
      avg_quality_score: Contact.average(:data_quality_score)&.round(2),
      issues: []
    }

    # Identify common issues
    summary[:issues] << "#{Contact.where(email: nil).count} contacts missing email" if Contact.where(email: nil).count > 0
    summary[:issues] << "#{Contact.where(business_enriched: false).count} contacts not enriched" if Contact.where(business_enriched: false).count > 0
    summary[:issues] << "#{Contact.high_risk.count} high-risk contacts" if Contact.high_risk.count > 0

    prompt = <<~PROMPT
      Analyze this contact database quality summary:

      #{summary.to_json}

      Provide:
      1. Top 3 data quality issues to address
      2. Recommended actions to improve data quality
      3. Estimated impact of improvements
      4. Priority order for fixes

      Keep response concise and actionable.
    PROMPT

    query(prompt)
  end

  # Industry insights
  def analyze_industry_distribution
    return { error: "AI features not enabled" } unless ai_enabled?

    industries = Contact.group(:business_industry).count
    top_industries = industries.sort_by { |_, count| -count }.first(10)

    prompt = <<~PROMPT
      Analyze this industry distribution from our contact database:

      #{top_industries.to_h.to_json}

      Provide:
      1. Market opportunities based on industry concentration
      2. Underserved industries worth targeting
      3. Industry-specific outreach recommendations
      4. Risk factors by industry

      Keep response strategic and sales-focused.
    PROMPT

    query(prompt)
  end

  # Smart contact recommendations
  def recommend_contacts_for_outreach(criteria: {}, limit: 10)
    return { error: "AI features not enabled" } unless ai_enabled?

    # Build smart query based on criteria
    contacts = Contact.completed.high_quality

    contacts = contacts.where(business_employee_range: criteria[:size]) if criteria[:size]
    contacts = contacts.where(business_industry: criteria[:industry]) if criteria[:industry]
    contacts = contacts.where(sms_pumping_risk_level: 'low') unless criteria[:allow_risk]

    contacts = contacts.limit(limit)

    summary = contacts.map { |c| build_contact_summary(c) }.join("\n\n---\n\n")

    prompt = <<~PROMPT
      Rank these contacts for sales outreach priority:

      #{summary}

      For each contact, provide:
      1. Priority score (1-10)
      2. Best outreach angle
      3. Talking points
      4. Potential objections

      Respond in JSON format with contact ID as key.
    PROMPT

    result = query(prompt)

    if result[:content]
      {
        content: result[:content],
        contacts: contacts,
        provider: result[:provider]
      }
    else
      result
    end
  end

  # Get cost-effective provider for task
  def self.best_provider_for(task_type)
    case task_type
    when :quick_query
      'google'  # Gemini Flash is cheapest
    when :complex_analysis
      'anthropic'  # Claude excels at analysis
    when :creative_writing
      'openai'  # GPT-4 for creative tasks
    when :access_all_models
      'openrouter'  # Access to 100+ models through single API
    else
      TwilioCredential.current&.preferred_llm_provider || 'openai'
    end
  end

  private

  def ai_enabled?
    return false unless @credentials&.enable_ai_features

    # Check if at least one LLM provider is configured
    has_openai = @credentials.enable_ai_features && @credentials.openai_api_key.present?
    has_anthropic = @credentials.enable_anthropic && @credentials.anthropic_api_key.present?
    has_google = @credentials.enable_google_ai && @credentials.google_ai_api_key.present?
    has_openrouter = @credentials.enable_openrouter && @credentials.openrouter_api_key.present?

    has_openai || has_anthropic || has_google || has_openrouter
  end

  def preferred_provider
    @credentials&.preferred_llm_provider || 'openai'
  end

  def build_contact_summary(contact)
    summary = ["Contact ID: #{contact.id}"]
    summary << "Phone: #{contact.formatted_phone_number}"
    summary << "Name: #{contact.full_name}" if contact.full_name.present?

    if contact.business?
      summary << "Company: #{contact.business_name}"
      summary << "Industry: #{contact.business_industry}" if contact.business_industry.present?
      summary << "Size: #{contact.business_size_category}" if contact.business_employee_range.present?
      summary << "Revenue: #{contact.business_revenue_range}" if contact.business_revenue_range.present?
    end

    summary << "Quality Score: #{contact.data_quality_score}%" if contact.data_quality_score
    summary << "Risk Level: #{contact.sms_pumping_risk_level}" if contact.sms_pumping_risk_level.present?

    summary.join("\n")
  end
end
