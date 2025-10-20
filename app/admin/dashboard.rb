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
                if Redis.new.ping == "PONG"
                  status_tag "Connected", class: "completed"
                else
                  status_tag "Disconnected", class: "failed"
                end
              rescue => e
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
              rescue
                "Not configured"
              end
            end
          end
        end
      end
    end
  end
end
