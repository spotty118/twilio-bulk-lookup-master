ActiveAdmin.register_page "AI Assistant" do
  menu priority: 4, label: "AI Assistant"

  content do
    credentials = TwilioCredential.current

    unless credentials&.enable_ai_features && credentials.openai_api_key.present?
      panel "⚠️ AI Features Not Configured" do
        div style: "text-align: center; padding: 40px;" do
          para "AI features are not enabled or OpenAI API key is missing.", style: "color: #dc3545; font-size: 16px; margin-bottom: 20px;"
          para "Enable AI features and add your OpenAI API key in settings.", style: "color: #6c757d;"
          settings_path = credentials ? edit_admin_twilio_credential_path(credentials) : new_admin_twilio_credential_path
          link_to "Go to Settings", settings_path, class: "button primary", style: "margin-top: 20px;"
        end
      end
      next
    end

    columns do
      column do
        panel "🔍 Natural Language Search" do
          div style: "background: #e7f3ff; padding: 20px; border-radius: 8px; margin-bottom: 20px;" do
            h3 "Ask AI to Find Contacts", style: "margin-top: 0;"
            para "Use natural language to search your contacts. AI will understand your intent and find matches.", style: "margin: 0;"
          end

          form action: ai_search_admin_ai_assistant_path, method: :get do |f|
            div style: "margin-bottom: 15px;" do
              label "What are you looking for?", style: "display: block; margin-bottom: 5px; font-weight: bold;"
              input type: "text",
                    name: "query",
                    value: params[:query],
                    placeholder: "e.g., 'Find tech companies in California with 50+ employees'",
                    style: "width: 100%; padding: 12px; font-size: 14px; border: 1px solid #ddd; border-radius: 4px;",
                    autofocus: true
            end

            div do
              input type: "submit", value: "🔍 Search with AI", class: "button primary", style: "font-size: 16px;"
            end
          end

          if params[:query].present?
            div style: "margin-top: 30px; padding: 20px; background: #f8f9fa; border-radius: 8px;" do
              h4 "Search Results", style: "margin-top: 0;"

              # Call AI service
              result = AiAssistantService.natural_language_search(params[:query])

              if result[:error]
                div style: "color: #dc3545; padding: 15px; background: #f8d7da; border-radius: 4px;" do
                  strong "Error: "
                  text_node result[:error]
                end
              elsif result[:filters]
                # Display AI interpretation
                div style: "margin-bottom: 20px; padding: 15px; background: #d1ecf1; border-radius: 4px; border-left: 4px solid #0c5460;" do
                  strong "AI understood your query as: "
                  para result[:explanation], style: "margin: 5px 0 0 0;"
                end

                # Build ActiveAdmin-style search
                begin
                  contacts = Contact.all

                  # Fields that support partial matching with ILIKE
                  ilike_fields = %w[business_name business_city business_state business_country].freeze

                  result[:filters].each do |field, value|
                    # Type-safe query building using Arel with runtime column validation
                    if ilike_fields.include?(field) && Contact.column_names.include?(field)
                      # Arel provides SQL injection protection via parameterized queries
                      contacts = contacts.where(Contact.arel_table[field].matches("%#{value}%"))
                    elsif %w[business_industry business_type business_employee_range business_revenue_range line_type sms_pumping_risk_level status].include?(field)
                      # Exact match fields - hash-based where is always safe
                      contacts = contacts.where(field => value)
                    elsif %w[is_business email_verified].include?(field)
                      # Boolean fields with string conversion
                      contacts = contacts.where(field => value == 'true' || value == true)
                    end
                  end

                  contacts = contacts.limit(50)

                  if contacts.any?
                    div style: "margin-top: 20px;" do
                      strong "Found #{contacts.count} matching contacts:", style: "display: block; margin-bottom: 10px;"

                      table_for contacts do
                        column("Name") do |c|
                          link_to c.business_display_name, admin_contact_path(c), style: "font-weight: bold;"
                        end
                        column("Phone") { |c| c.formatted_phone_number }
                        column("Email") { |c| c.email || "—" }
                        column("Type") do |c|
                          if c.business?
                            "🏢 #{c.business_industry || 'Business'}"
                          else
                            "👤 Consumer"
                          end
                        end
                        column("Quality") { |c| c.data_quality_score ? "#{c.data_quality_score}/100" : "—" }
                        column("Actions") do |c|
                          link_to "View", admin_contact_path(c), class: "button"
                        end
                      end
                    end
                  else
                    para "No contacts found matching these criteria.", style: "color: #6c757d; padding: 20px; text-align: center;"
                  end
                rescue StandardError => e
                  div style: "color: #dc3545; padding: 15px; background: #f8d7da; border-radius: 4px;" do
                    strong "Search Error: "
                    text_node e.message
                  end
                end
              end
            end
          else
            div style: "margin-top: 20px; padding: 20px; background: #fff3cd; border-radius: 8px; border-left: 4px solid #ffc107;" do
              strong "💡 Example Queries:"
              ul style: "margin: 10px 0 0 20px;" do
                li "Find tech companies in San Francisco"
                li "Show me enterprise businesses with high revenue"
                li "Businesses with verified emails in healthcare"
                li "Mobile contacts with low fraud risk"
                li "Companies with 200-500 employees"
              end
            end
          end
        end
      end

      column do
        panel "💬 AI Question Answering" do
          div style: "background: #e7f3ff; padding: 20px; border-radius: 8px; margin-bottom: 20px;" do
            h3 "Ask Questions About Your Data", style: "margin-top: 0;"
            para "Get insights, trends, and recommendations from your contact database.", style: "margin: 0;"
          end

          form action: ai_query_admin_ai_assistant_path, method: :post do |f|
            input type: "hidden", name: "authenticity_token", value: form_authenticity_token

            div style: "margin-bottom: 15px;" do
              label "Your Question:", style: "display: block; margin-bottom: 5px; font-weight: bold;"
              textarea name: "prompt",
                       placeholder: "e.g., 'What industries should I focus on?' or 'Analyze my contact quality'",
                       style: "width: 100%; padding: 12px; font-size: 14px; border: 1px solid #ddd; border-radius: 4px; min-height: 100px;"
            end

            div do
              input type: "submit", value: "💡 Ask AI", class: "button primary", style: "font-size: 16px;"
            end
          end

          if params[:ai_response].present?
            div style: "margin-top: 20px; padding: 20px; background: #d4edda; border-radius: 8px; border-left: 4px solid #28a745;" do
              h4 "AI Response:", style: "margin-top: 0;"
              div style: "white-space: pre-wrap; line-height: 1.6;" do
                text_node params[:ai_response]
              end
            end
          end
        end

        panel "📝 Quick Stats for AI Context" do
          div style: "font-size: 13px; color: #6c757d;" do
            ul style: "margin: 0; padding-left: 20px;" do
              li "Total Contacts: #{Contact.count}"
              li "Businesses: #{Contact.businesses.count}"
              li "Verified Emails: #{Contact.with_verified_email.count}"
              li "High Risk: #{Contact.high_risk.count}"
              li "Top Industry: #{Contact.businesses.where.not(business_industry: nil).group(:business_industry).count.max_by { |_, v| v }&.first || 'N/A'}"
              li "Data Quality Avg: #{Contact.average(:data_quality_score)&.round || 'N/A'}"
            end
          end
        end
      end
    end
  end

  # AI Search action
  page_action :ai_search, method: :get do
    # Handled in content block above
    render :index
  end

  # AI Query action
  page_action :ai_query, method: :post do
    prompt = params[:prompt]

    if prompt.blank?
      redirect_to admin_ai_assistant_path, alert: "Please enter a question"
      return
    end

    # Build context about the database
    context = <<~CONTEXT
      Database stats:
      - Total contacts: #{Contact.count}
      - Businesses: #{Contact.businesses.count}
      - Consumers: #{Contact.consumers.count}
      - Verified emails: #{Contact.with_verified_email.count}
      - High risk contacts: #{Contact.high_risk.count}
      - Top 3 industries: #{Contact.businesses.where.not(business_industry: nil).group(:business_industry).count.sort_by { |_, v| -v }.first(3).map { |k, v| "#{k} (#{v})" }.join(', ')}
    CONTEXT

    response = AiAssistantService.query(prompt, context: context)

    if response.is_a?(Hash) && response[:error].present?
      redirect_to admin_ai_assistant_path, alert: response[:error]
    elsif response.present?
      redirect_to admin_ai_assistant_path(ai_response: response)
    else
      redirect_to admin_ai_assistant_path, alert: "AI request failed. Please try again."
    end
  end
end
