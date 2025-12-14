ActiveAdmin.register_page "Dashboard" do
  
  menu priority: 1, label: proc{ I18n.t("active_admin.dashboard") }
  
  content title: proc{ I18n.t("active_admin.dashboard") } do

    # Subscribe to turbo stream updates
    div id: "turbo-stream-target" do
      turbo_stream_from "dashboard_stats"
    end

    # Render stats partial
    render partial: 'admin/dashboard/stats'

    # Recalculate stats for use in remaining sections
    total_count = Contact.count
    pending_count = Contact.pending.count
    processing_count = Contact.processing.count
    completed_count = Contact.completed.count
    failed_count = Contact.failed.count
    completion_percentage = total_count > 0 ? (completed_count.to_f / total_count * 100).round(1) : 0
    
    # ========================================
    # Processing Controls & Quick Actions
    # ========================================
    columns do
      column do
        panel "🚀 Bulk Lookup Controls" do
          if pending_count + failed_count > 0
            button_to "▶ Start Processing (#{pending_count + failed_count} contacts)", 
                      '/lookup', 
                      method: :get, 
                      class: "button primary",
                      style: "font-size: 16px; padding: 15px 30px; margin-bottom: 15px; width: 100%;"
            para "Processes all pending and failed contacts in the background.", style: "color: #6c757d;"
          else
            para "✅ All contacts have been processed!", style: "color: #11998e; font-weight: bold; font-size: 16px; text-align: center; padding: 20px;"
          end
          
          div style: "display: flex; gap: 10px; margin-top: 15px;" do
            link_to "📊 Monitor Jobs", "/sidekiq", target: "_blank", class: "button", style: "flex: 1;"
            link_to "📞 View Contacts", admin_contacts_path, class: "button", style: "flex: 1;"
            link_to "⚙️ Settings", admin_twilio_credentials_path, class: "button", style: "flex: 1;"
          end
        end
      end
      
      column do
        panel "📈 Processing Summary" do
          attributes_table_for nil do
            row("Status") do
              if processing_count > 0
                status_tag "Processing #{processing_count} contacts...", class: "processing"
              elsif pending_count > 0
                status_tag "#{pending_count} contacts waiting", class: "pending"
              elsif failed_count > 0
                status_tag "#{failed_count} failures need attention", class: "failed"
              else
                status_tag "All complete", class: "completed"
              end
            end
            
            row("Completion") { "#{completion_percentage}% (#{completed_count} of #{total_count})" }
            
            if failed_count > 0
              row("Failed") do
                link_to "⚠️ View #{failed_count} Failed Contacts", 
                        admin_contacts_path(q: {status_eq: 'failed'}),
                        style: "color: #dc3545; font-weight: bold;"
              end
            end
            
            if total_count > 0
              avg_time = Contact.where.not(lookup_performed_at: nil)
                               .average("EXTRACT(EPOCH FROM (lookup_performed_at - created_at))")
              if avg_time
                row("Avg Processing Time") { "#{avg_time.round(1)} seconds" }
              end
            end
          end
        end
      end

      column do
        panel "📞 Quick Phone Lookup" do
          form action: admin_dashboard_phone_lookup_path, method: :post do |f|
            f.input type: :hidden, name: :authenticity_token, value: form_authenticity_token

            div class: "input string required", style: "margin-bottom: 15px;" do
              label "Phone Number", for: "phone_number", class: "label"
              input type: "text",
                    name: "phone_number",
                    id: "phone_number",
                    value: flash[:phone_lookup_input],
                    placeholder: "+14155552671",
                    required: true,
                    style: "width: 100%; padding: 10px; font-size: 16px; font-family: monospace;"
              span "E.164 format recommended", class: "inline-hints", style: "color: #6c757d; font-size: 12px;"
            end

            div class: "actions" do
              input type: "submit",
                    value: "🔎 Lookup",
                    class: "button primary",
                    style: "font-size: 16px; padding: 12px 20px; width: 100%;"
            end
          end

          if flash[:phone_lookup_error].present?
            div style: "margin-top: 15px; padding: 12px; background: #f8d7da; border-left: 4px solid #dc3545; border-radius: 4px;" do
              strong "Lookup failed", style: "color: #721c24;"
              div style: "margin-top: 8px; color: #721c24; font-family: monospace; font-size: 12px; white-space: pre-wrap;" do
                text_node flash[:phone_lookup_error]
              end
            end
          elsif flash[:phone_lookup_result].present?
            result = flash[:phone_lookup_result]
            result = result.with_indifferent_access if result.respond_to?(:with_indifferent_access)

            lti = result[:line_type_intelligence] || {}
            lti = lti.with_indifferent_access if lti.respond_to?(:with_indifferent_access)

            cnam = result[:caller_name] || {}
            cnam = cnam.with_indifferent_access if cnam.respond_to?(:with_indifferent_access)

            risk = result[:sms_pumping_risk] || {}
            risk = risk.with_indifferent_access if risk.respond_to?(:with_indifferent_access)

            attributes_table_for nil do
              row("Formatted") { result[:phone_number].presence || "—" }
              row("Valid") do
                if result[:phone_valid].nil?
                  status_tag "Unknown", class: "warning"
                elsif result[:phone_valid]
                  status_tag "Valid", class: "ok"
                else
                  status_tag "Invalid", class: "error"
                end
              end

              row("Country") do
                parts = [result[:country_code], result[:calling_country_code]].compact
                parts.any? ? parts.join(" / ") : "—"
              end

              row("Line Type") do
                if lti[:type].present?
                  status_tag lti[:type], class: lti[:type]
                else
                  "—"
                end
              end

              row("Carrier") { lti[:carrier_name].presence || "—" }
              row("CNAM") { cnam[:caller_name].presence || "—" }
              row("Caller Type") { cnam[:caller_type].presence || "—" }

              row("Fraud Risk Score") { risk[:sms_pumping_risk_score].presence || "—" }
              row("Blocked") do
                blocked = risk[:number_blocked]
                if blocked.nil?
                  "—"
                elsif blocked
                  status_tag "Yes", class: "error"
                else
                  status_tag "No", class: "ok"
                end
              end
            end
          end
        end
      end
    end
    
    # ========================================
    # Fraud Analytics
    # ========================================
    columns do
      column do
        panel "🛡️ SMS Pumping Fraud Detection" do
          high_risk_count = Contact.high_risk.count
          medium_risk_count = Contact.medium_risk.count
          low_risk_count = Contact.low_risk.count
          blocked_count = Contact.blocked_numbers.count
          total_assessed = high_risk_count + medium_risk_count + low_risk_count
          
          if total_assessed > 0
            attributes_table_for nil do
              row("High Risk Numbers") do
                if high_risk_count > 0
                  link_to "🚨 #{high_risk_count} numbers", 
                          admin_contacts_path(scope: 'high_risk'),
                          style: "color: #dc3545; font-weight: bold; font-size: 16px;"
                else
                  status_tag "0 numbers", class: "ok"
                end
              end
              
              row("Medium Risk Numbers") do
                if medium_risk_count > 0
                  link_to "⚠️ #{medium_risk_count} numbers", 
                          admin_contacts_path(scope: 'medium_risk'),
                          style: "color: #f39c12; font-weight: bold;"
                else
                  status_tag "0 numbers", class: "ok"
                end
              end
              
              row("Low Risk Numbers") do
                link_to "✅ #{low_risk_count} numbers", 
                        admin_contacts_path(scope: 'low_risk'),
                        style: "color: #11998e;"
              end
              
              row("Blocked Numbers") do
                if blocked_count > 0
                  link_to "🚫 #{blocked_count} blocked", 
                          admin_contacts_path(scope: 'blocked_numbers'),
                          style: "color: #721c24; font-weight: bold; font-size: 16px;"
                else
                  status_tag "None blocked", class: "ok"
                end
              end
              
              row("Risk Distribution") do
                high_pct = (high_risk_count.to_f / total_assessed * 100).round(1)
                medium_pct = (medium_risk_count.to_f / total_assessed * 100).round(1)
                low_pct = (low_risk_count.to_f / total_assessed * 100).round(1)
                
                div style: "margin-top: 10px;" do
                  div style: "display: flex; gap: 15px; margin-bottom: 5px;" do
                    span "High: #{high_pct}%", style: "color: #dc3545;"
                    span "Medium: #{medium_pct}%", style: "color: #f39c12;"
                    span "Low: #{low_pct}%", style: "color: #11998e;"
                  end
                  
                  div class: "progress-bar", style: "height: 25px; display: flex; border-radius: 4px; overflow: hidden;" do
                    if high_pct > 0
                      div style: "width: #{high_pct}%; background: #dc3545; display: flex; align-items: center; justify-content: center; color: white; font-size: 11px;" do
                        "#{high_pct}%" if high_pct > 10
                      end
                    end
                    if medium_pct > 0
                      div style: "width: #{medium_pct}%; background: #f39c12; display: flex; align-items: center; justify-content: center; color: white; font-size: 11px;" do
                        "#{medium_pct}%" if medium_pct > 10
                      end
                    end
                    if low_pct > 0
                      div style: "width: #{low_pct}%; background: #11998e; display: flex; align-items: center; justify-content: center; color: white; font-size: 11px;" do
                        "#{low_pct}%" if low_pct > 10
                      end
                    end
                  end
                end
              end
            end
          else
            para "No fraud risk data available yet. Process contacts with SMS Pumping Risk detection enabled.", 
                 style: "color: #6c757d; text-align: center; padding: 30px;"
          end
        end
      end
      
      column do
        panel "📊 Line Type Distribution" do
          mobile_count = Contact.mobile.count
          landline_count = Contact.landline.count
          voip_count = Contact.voip.count
          total_typed = mobile_count + landline_count + voip_count
          
          if total_typed > 0
            attributes_table_for nil do
              row("Mobile") do
                pct = (mobile_count.to_f / total_typed * 100).round(1)
                "📱 #{mobile_count} (#{pct}%)"
              end
              
              row("Landline") do
                pct = (landline_count.to_f / total_typed * 100).round(1)
                "☎️ #{landline_count} (#{pct}%)"
              end
              
              row("VoIP") do
                pct = (voip_count.to_f / total_typed * 100).round(1)
                "💻 #{voip_count} (#{pct}%)"
              end
            end
            
            div style: "margin-top: 15px;" do
              mobile_pct = (mobile_count.to_f / total_typed * 100).round(1)
              landline_pct = (landline_count.to_f / total_typed * 100).round(1)
              voip_pct = (voip_count.to_f / total_typed * 100).round(1)
              
              div class: "progress-bar", style: "height: 25px; display: flex; border-radius: 4px; overflow: hidden;" do
                if mobile_pct > 0
                  div style: "width: #{mobile_pct}%; background: #667eea; display: flex; align-items: center; justify-content: center; color: white; font-size: 11px;" do
                    "Mobile #{mobile_pct}%" if mobile_pct > 15
                  end
                end
                if landline_pct > 0
                  div style: "width: #{landline_pct}%; background: #11998e; display: flex; align-items: center; justify-content: center; color: white; font-size: 11px;" do
                    "Landline #{landline_pct}%" if landline_pct > 15
                  end
                end
                if voip_pct > 0
                  div style: "width: #{voip_pct}%; background: #f093fb; display: flex; align-items: center; justify-content: center; color: white; font-size: 11px;" do
                    "VoIP #{voip_pct}%" if voip_pct > 15
                  end
                end
              end
            end
          else
            para "No line type data available. Enable Line Type Intelligence in lookups.", 
                 style: "color: #6c757d; text-align: center; padding: 30px;"
          end
        end
      end
    end

    # ========================================
    # Business Intelligence Analytics
    # ========================================
    columns do
      column do
        panel "🏢 Business Intelligence Overview" do
          total_businesses = Contact.businesses.count
          total_consumers = Contact.consumers.count
          enriched_count = Contact.business_enriched.count
          needs_enrichment_count = Contact.needs_enrichment.count
          
          if total_businesses > 0
            attributes_table_for nil do
              row("Total Businesses") do
                link_to "#{total_businesses} business contacts", 
                        admin_contacts_path(scope: 'businesses'),
                        style: "font-weight: bold; font-size: 16px; color: #667eea;"
              end
              
              row("Consumers") do
                link_to "#{total_consumers} consumer contacts", 
                        admin_contacts_path(scope: 'consumers'),
                        style: "color: #6c757d;"
              end
              
              row("Enriched") do
                if enriched_count > 0
                  enrichment_pct = (enriched_count.to_f / total_businesses * 100).round(1)
                  link_to "✅ #{enriched_count} enriched (#{enrichment_pct}%)", 
                          admin_contacts_path(scope: 'business_enriched'),
                          style: "color: #11998e; font-weight: bold;"
                else
                  status_tag "No businesses enriched yet", class: "warning"
                end
              end
              
              row("Needs Enrichment") do
                if needs_enrichment_count > 0
                  link_to "⏳ #{needs_enrichment_count} pending enrichment", 
                          admin_contacts_path(scope: 'needs_enrichment'),
                          style: "color: #f39c12; font-weight: bold;"
                else
                  status_tag "All enriched", class: "ok"
                end
              end
            end
            
            # Enrichment progress bar
            if total_businesses > 0
              enrichment_pct = (enriched_count.to_f / total_businesses * 100).round(1)
              div style: "margin-top: 15px;" do
                para "Enrichment Progress:", style: "margin-bottom: 5px; font-weight: bold;"
                div class: "progress-bar", style: "height: 25px; background: #e9ecef;" do
                  div style: "width: #{enrichment_pct}%; background: #11998e; height: 100%; display: flex; align-items: center; justify-content: center; color: white; font-size: 12px; font-weight: bold;" do
                    "#{enrichment_pct}%"
                  end
                end
              end
            end
          else
            para "No business contacts identified yet. Process contacts with Caller Name (CNAM) enabled.", 
                 style: "color: #6c757d; text-align: center; padding: 30px;"
          end
        end
      end
      
      column do
        panel "📊 Top Industries" do
          industry_stats = Contact.businesses
                                 .where.not(business_industry: nil)
                                 .group(:business_industry)
                                 .count
                                 .sort_by { |_, count| -count }
                                 .take(8)
          
          if industry_stats.any?
            total_with_industry = industry_stats.sum { |_, count| count }
            
            table_for industry_stats do
              column("Industry") { |industry, count| industry }
              column("Companies") { |industry, count| count }
              column("Percentage") do |industry, count|
                percentage = (count.to_f / total_with_industry * 100).round(1)
                "#{percentage}%"
              end
              column("Visual") do |industry, count|
                percentage = (count.to_f / total_with_industry * 100).round(1)
                div class: "progress-bar", style: "height: 20px; margin: 0; background: #e9ecef;" do
                  div style: "width: #{percentage}%; background: #667eea; height: 100%; display: flex; align-items: center; justify-content: center; color: white; font-size: 10px;" do
                    "#{percentage}%" if percentage > 15
                  end
                end
              end
            end
          else
            para "No industry data available. Enable business enrichment to see industry breakdown.", 
                 style: "color: #6c757d; text-align: center; padding: 30px;"
          end
        end
      end
    end
    
    columns do
      column do
        panel "🏭 Company Size Distribution" do
          size_stats = Contact.businesses
                             .where.not(business_employee_range: nil)
                             .group(:business_employee_range)
                             .count
          
          if size_stats.any?
            # Order by size
            size_order = ['1-10', '11-50', '51-200', '201-500', '501-1000', '1001-5000', '5001-10000', '10000+']
            ordered_stats = size_order.map { |size| [size, size_stats[size] || 0] }.select { |_, count| count > 0 }
            total_with_size = ordered_stats.sum { |_, count| count }
            
            table_for ordered_stats do
              column("Company Size") do |size, count|
                case size
                when '1-10' then "Micro (1-10)"
                when '11-50' then "Small (11-50)"
                when '51-200' then "Medium (51-200)"
                when '201-500', '501-1000' then "Large (#{size})"
                else "Enterprise (#{size})"
                end
              end
              column("Count") { |size, count| count }
              column("Percentage") do |size, count|
                percentage = (count.to_f / total_with_size * 100).round(1)
                "#{percentage}%"
              end
            end
          else
            para "No company size data available.", style: "color: #6c757d; text-align: center; padding: 30px;"
          end
        end
      end
      
      column do
        panel "💰 Revenue Distribution" do
          revenue_stats = Contact.businesses
                                .where.not(business_revenue_range: nil)
                                .group(:business_revenue_range)
                                .count
          
          if revenue_stats.any?
            # Order by revenue
            revenue_order = ['$0-$1M', '$1M-$10M', '$10M-$50M', '$50M-$100M', '$100M-$500M', '$500M-$1B', '$1B+']
            ordered_stats = revenue_order.map { |range| [range, revenue_stats[range] || 0] }.select { |_, count| count > 0 }
            total_with_revenue = ordered_stats.sum { |_, count| count }
            
            table_for ordered_stats do
              column("Revenue Range") { |range, count| range }
              column("Count") { |range, count| count }
              column("Percentage") do |range, count|
                percentage = (count.to_f / total_with_revenue * 100).round(1)
                "#{percentage}%"
              end
            end
          else
            para "No revenue data available.", style: "color: #6c757d; text-align: center; padding: 30px;"
          end
        end
      end
    end
    
    # ========================================
    # Interactive Charts
    # ========================================
    columns do
      column do
        panel "📊 Status Distribution Over Time" do
          # Prepare data for line chart (last 7 days)
          days_ago = 7.days.ago.to_date
          date_range = (days_ago..Date.today).to_a
          
          chart_data = {
            labels: date_range.map { |d| d.strftime("%b %d") },
            datasets: [
              {
                label: 'Completed',
                data: date_range.map { |d| Contact.completed.where('DATE(lookup_performed_at) = ?', d).count },
                borderColor: '#11998e',
                backgroundColor: 'rgba(17, 153, 142, 0.1)',
                tension: 0.4
              },
              {
                label: 'Failed',
                data: date_range.map { |d| Contact.failed.where('DATE(lookup_performed_at) = ?', d).count },
                borderColor: '#eb3349',
                backgroundColor: 'rgba(235, 51, 73, 0.1)',
                tension: 0.4
              }
            ]
          }
          
          div do
            canvas id: "status-timeline-chart", style: "max-height: 300px;"
          end
          
          script type: "text/javascript" do
            raw <<-JAVASCRIPT
              (function() {
                if (typeof Chart === 'undefined') {
                  var script = document.createElement('script');
                  script.src = 'https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js';
                  script.onload = function() { initStatusChart(); };
                  document.head.appendChild(script);
                } else {
                  initStatusChart();
                }
                
                function initStatusChart() {
                  var ctx = document.getElementById('status-timeline-chart');
                  if (ctx && !ctx.chart) {
                    ctx.chart = new Chart(ctx, {
                      type: 'line',
                      data: #{chart_data.to_json},
                      options: {
                        responsive: true,
                        maintainAspectRatio: false,
                        plugins: {
                          legend: { display: true, position: 'top' },
                          title: { display: false }
                        },
                        scales: {
                          y: { beginAtZero: true, ticks: { precision: 0 } }
                        }
                      }
                    });
                  }
                }
              })();
            JAVASCRIPT
          end
        end
      end
      
      column do
        panel "📱 Device Type Breakdown" do
          # Prepare data for pie chart
          device_data = Contact.completed.group(:device_type).count
          
          if device_data.any?
            chart_data = {
              labels: device_data.keys.map { |k| k || 'Unknown' },
              datasets: [{
                data: device_data.values,
                backgroundColor: ['#667eea', '#11998e', '#f093fb', '#5E6BFF', '#eb3349'],
                borderWidth: 2,
                borderColor: '#ffffff'
              }]
            }
            
            div do
              canvas id: "device-type-chart", style: "max-height: 300px;"
            end
            
            script type: "text/javascript" do
              raw <<-JAVASCRIPT
                (function() {
                  if (typeof Chart === 'undefined') {
                    var script = document.createElement('script');
                    script.src = 'https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js';
                    script.onload = function() { initDeviceChart(); };
                    document.head.appendChild(script);
                  } else {
                    initDeviceChart();
                  }
                  
                  function initDeviceChart() {
                    var ctx = document.getElementById('device-type-chart');
                    if (ctx && !ctx.chart) {
                      ctx.chart = new Chart(ctx, {
                        type: 'pie',
                        data: #{chart_data.to_json},
                        options: {
                          responsive: true,
                          maintainAspectRatio: false,
                          plugins: {
                            legend: { display: true, position: 'right' }
                          }
                        }
                      });
                    }
                  }
                })();
              JAVASCRIPT
            end
          else
            para "No device type data available yet. Process contacts to see breakdown.", 
                 style: "color: #6c757d; text-align: center; padding: 40px;"
          end
        end
      end
    end

    # ========================================
    # Device Type Breakdown
    # ========================================
    if completed_count > 0
      columns do
        column do
          panel "📱 Device Type Distribution" do
            device_stats = Contact.completed
                                 .group(:device_type)
                                 .count
                                 .sort_by { |_, count| -count }
            
            if device_stats.any?
              table_for device_stats do
                column("Device Type") do |device_type, count|
                  status_tag device_type || "Unknown", class: device_type
                end
                column("Count") { |device_type, count| count }
                column("Percentage") do |device_type, count|
                  percentage = (count.to_f / completed_count * 100).round(1)
                  "#{percentage}%"
                end
                column("Visual") do |device_type, count|
                  percentage = (count.to_f / completed_count * 100).round(1)
                  div class: "progress-bar", style: "height: 20px; margin: 0;" do
                    div class: "progress-fill", style: "width: #{percentage}%; font-size: 11px;" do
                      "#{percentage}%"
                    end
                  end
                end
              end
            else
              para "No device type data available yet.", class: "blank_slate"
            end
          end
        end
        
        column do
          panel "🏢 Top Carriers" do
            carrier_stats = Contact.completed
                                  .where.not(carrier_name: nil)
                                  .group(:carrier_name)
                                  .count
                                  .sort_by { |_, count| -count }
                                  .take(10)
            
            if carrier_stats.any?
              table_for carrier_stats do
                column("Carrier") { |carrier, count| carrier }
                column("Count") { |carrier, count| count }
                column("Percentage") do |carrier, count|
                  percentage = (count.to_f / completed_count * 100).round(1)
                  "#{percentage}%"
                end
              end
            else
              para "No carrier data available yet.", class: "blank_slate"
            end
          end
        end
      end
    end
    
    # ========================================
    # Recent Activity
    # ========================================
    columns do
      column do
        panel "✅ Recent Successful Lookups (Last 10)" do
          recent_success = Contact.completed.order(lookup_performed_at: :desc).limit(10)
          
          if recent_success.any?
            table_for recent_success do
              column("Phone") { |contact| contact.formatted_phone_number || contact.raw_phone_number }
              column("Carrier") { |contact| contact.carrier_name }
              column("Type") do |contact|
                status_tag contact.device_type if contact.device_type
              end
              column("Completed") { |contact| contact.lookup_performed_at&.strftime("%b %d, %H:%M") }
            end
          else
            para "No completed lookups yet. Click 'Start Processing' to begin.", class: "blank_slate"
          end
        end
      end
      
      column do
        panel "❌ Recent Failures (Last 10)" do
          recent_failures = Contact.failed.order(updated_at: :desc).limit(10)
          
          if recent_failures.any?
            table_for recent_failures do
              column("Phone") { |contact| contact.raw_phone_number }
              column("Error") { |contact| truncate(contact.error_code, length: 40) }
              column("Failed") { |contact| contact.lookup_performed_at&.strftime("%b %d, %H:%M") }
              column("Actions") do |contact|
                if contact.retriable?
                  link_to "Retry", retry_admin_contact_path(contact), method: :post, class: "button"
                else
                  span "Permanent", style: "color: #dc3545;"
                end
              end
            end
          else
            para "✅ No failures recorded - great job!", class: "blank_slate", style: "color: #11998e;"
          end
        end
      end
    end
    
    # ========================================
    # System Health & Info
    # ========================================
    columns do
      column do
        panel "💚 System Health" do
          attributes_table_for nil do
            row("Redis Connection") do
              begin
                redis = Redis.new
                result = redis.ping == "PONG"
                redis.close rescue nil  # Ensure connection is closed
                if result
                  status_tag "Connected", class: "completed"
                else
                  status_tag "Disconnected", class: "failed"
                end
              rescue StandardError => e
                status_tag "Error: #{e.message}", class: "failed"
              end
            end
            
            row("Sidekiq Jobs") { link_to("Monitor Background Jobs →", "/sidekiq", target: "_blank") }
            
            row("Twilio Credentials") do
              if TwilioCredential.current.present?
                status_tag "Configured", class: "completed"
              else
                status_tag "Not Configured", class: "failed"
              end
            end
            
            row("Database Size") { "#{Contact.count} contacts" }
          end
        end
      end
      
      column do
        panel "ℹ️ System Information" do
          attributes_table_for nil do
            row("Rails Version") { Rails.version }
            row("Ruby Version") { RUBY_VERSION }
            row("Environment") { Rails.env.titleize }
            row("Sidekiq Concurrency") do
              begin
                config = YAML.load_file(Rails.root.join('config', 'sidekiq.yml'))
                config.dig(Rails.env, 'concurrency') || config['concurrency'] || "Default (5)"
              rescue StandardError => e
                "Not configured"
              end
            end
          end
        end
      end
    end
  end

  page_action :phone_lookup, method: :post do
    phone_number = params[:phone_number].to_s.strip

    if phone_number.blank?
      redirect_to admin_dashboard_path, alert: "Please enter a phone number"
      return
    end

    credentials = TwilioCredential.current
    app_creds = defined?(AppConfig) ? AppConfig.twilio_credentials : nil

    account_sid = app_creds&.dig(:account_sid)&.presence || credentials&.account_sid&.presence
    auth_token = app_creds&.dig(:auth_token)&.presence || credentials&.auth_token&.presence

    unless account_sid.present? && auth_token.present?
      redirect_to admin_dashboard_path, alert: "No Twilio credentials configured"
      return
    end

    client = Twilio::REST::Client.new(account_sid, auth_token)
    fields = credentials&.data_packages

    lookup_result = if fields.present?
                      client.lookups
                            .v2
                            .phone_numbers(phone_number)
                            .fetch(fields: fields)
                    else
                      client.lookups
                            .v2
                            .phone_numbers(phone_number)
                            .fetch
                    end

    flash[:phone_lookup_input] = phone_number
    flash[:phone_lookup_result] = {
      phone_number: lookup_result.phone_number,
      national_format: lookup_result.national_format,
      country_code: lookup_result.country_code,
      calling_country_code: lookup_result.calling_country_code,
      phone_valid: lookup_result.valid,
      validation_errors: lookup_result.validation_errors || [],
      line_type_intelligence: lookup_result.line_type_intelligence || {},
      caller_name: lookup_result.caller_name || {},
      sms_pumping_risk: lookup_result.sms_pumping_risk || {}
    }

    redirect_to admin_dashboard_path
  rescue Twilio::REST::RestError => e
    flash[:phone_lookup_input] = phone_number
    flash[:phone_lookup_error] = e.message
    redirect_to admin_dashboard_path, alert: "Twilio lookup failed"
  rescue StandardError => e
    flash[:phone_lookup_input] = phone_number
    flash[:phone_lookup_error] = "#{e.class}: #{e.message}"
    redirect_to admin_dashboard_path, alert: "Lookup failed"
  end
end
