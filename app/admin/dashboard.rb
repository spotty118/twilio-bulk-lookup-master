ActiveAdmin.register_page 'Dashboard' do
  menu priority: 1, label: proc { I18n.t('active_admin.dashboard') }

  content title: proc { I18n.t('active_admin.dashboard') } do
    # Core stats (materialized view)
    stats = DashboardStats.current
    total_count = stats.total_contacts.to_i
    pending_count = stats.pending_count.to_i
    processing_count = stats.processing_count.to_i
    completed_count = stats.completed_count.to_i
    failed_count = stats.failed_count.to_i

    # Device type stats
    mobile_count = stats.mobile_count.to_i
    landline_count = stats.landline_count.to_i
    voip_count = stats.voip_count.to_i

    # Top carriers
    top_carriers = Contact.where.not(carrier_name: [nil, '']).group(:carrier_name).order('count_all DESC').limit(5).count

    # High risk count (for breakdown panel)
    high_risk = stats.high_risk_count.to_i

    # Daily lookups (last 7 days)
    daily_lookups = (0..6).map do |days_ago|
      date = days_ago.days.ago.to_date
      count = Contact.where(lookup_performed_at: date.beginning_of_day..date.end_of_day).count
      { date: date.strftime('%b %d'), count: count }
    end.reverse

    # Business vs Consumer
    business_count = stats.business_count.to_i
    consumer_count = [total_count - business_count, 0].max

    # Chart.js CDN
    script src: 'https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js'

    # ========================================
    # Stats Overview (materialized view + live updates)
    # ========================================
    render partial: 'admin/dashboard/stats', locals: { stats: stats }

    # ========================================
    # Charts Row - Two columns
    # ========================================
    div style: 'display: flex; gap: 20px; margin-bottom: 30px;' do
      # Status Distribution
      div style: 'flex: 1; background: #fff; border-radius: 8px; padding: 20px; box-shadow: 0 1px 3px rgba(0,0,0,0.1);' do
        div 'Status Distribution', style: 'font-size: 16px; font-weight: 600; color: #1f2937; margin-bottom: 16px;'
        div style: 'height: 250px; position: relative;' do
          canvas id: 'statusChart'
        end
      end

      # Device Types
      div style: 'flex: 1; background: #fff; border-radius: 8px; padding: 20px; box-shadow: 0 1px 3px rgba(0,0,0,0.1);' do
        div 'Device Types', style: 'font-size: 16px; font-weight: 600; color: #1f2937; margin-bottom: 16px;'
        div style: 'height: 250px; position: relative;' do
          canvas id: 'deviceChart'
        end
      end
    end

    # ========================================
    # Second Chart Row - Two columns
    # ========================================
    div style: 'display: flex; gap: 20px; margin-bottom: 30px;' do
      # Top Carriers
      div style: 'flex: 1; background: #fff; border-radius: 8px; padding: 20px; box-shadow: 0 1px 3px rgba(0,0,0,0.1);' do
        div 'Top Carriers', style: 'font-size: 16px; font-weight: 600; color: #1f2937; margin-bottom: 16px;'
        div style: 'height: 250px; position: relative;' do
          canvas id: 'carrierChart'
        end
      end

      # Lookups Over Time
      div style: 'flex: 1; background: #fff; border-radius: 8px; padding: 20px; box-shadow: 0 1px 3px rgba(0,0,0,0.1);' do
        div 'Lookups - Last 7 Days', style: 'font-size: 16px; font-weight: 600; color: #1f2937; margin-bottom: 16px;'
        div style: 'height: 250px; position: relative;' do
          canvas id: 'dailyChart'
        end
      end
    end

    # ========================================
    # Bottom Section - Actions and Status
    # ========================================
    div style: 'display: flex; gap: 20px; margin-bottom: 30px;' do
      # Actions Panel
      div style: 'flex: 1; background: #fff; border-radius: 8px; padding: 20px; box-shadow: 0 1px 3px rgba(0,0,0,0.1);' do
        div 'Actions', style: 'font-size: 16px; font-weight: 600; color: #1f2937; margin-bottom: 16px;'
        if pending_count + failed_count > 0
          div style: 'margin-bottom: 12px;' do
            link_to "Process #{pending_count + failed_count} Contacts", '/lookup',
                    style: 'display: block; width: 100%; padding: 12px; background: #2563eb; color: #fff; text-align: center; border-radius: 6px; text-decoration: none; font-weight: 500;'
          end
        else
          div 'All contacts processed', style: 'text-align: center; padding: 12px; color: #059669; font-weight: 500;'
        end
        div style: 'display: flex; gap: 10px;' do
          link_to 'View Contacts', admin_contacts_path,
                  style: 'flex: 1; padding: 10px; background: #f3f4f6; color: #374151; text-align: center; border-radius: 6px; text-decoration: none;'
          link_to 'Monitor Jobs', '/sidekiq', target: '_blank',
                  style: 'flex: 1; padding: 10px; background: #f3f4f6; color: #374151; text-align: center; border-radius: 6px; text-decoration: none;'
        end
      end

      # System Status Panel
      div style: 'flex: 1; background: #fff; border-radius: 8px; padding: 20px; box-shadow: 0 1px 3px rgba(0,0,0,0.1);' do
        div 'System Status', style: 'font-size: 16px; font-weight: 600; color: #1f2937; margin-bottom: 16px;'
        div style: 'display: flex; flex-direction: column; gap: 12px;' do
          # Current Status
          div style: 'display: flex; justify-content: space-between; align-items: center;' do
            span 'Current', style: 'color: #6b7280;'
            if processing_count > 0
              span "Processing #{processing_count}", style: 'background: #dbeafe; color: #1d4ed8; padding: 4px 10px; border-radius: 4px; font-size: 13px;'
            elsif pending_count > 0
              span "#{pending_count} waiting", style: 'background: #e0e7ff; color: #4338ca; padding: 4px 10px; border-radius: 4px; font-size: 13px;'
            else
              span 'Idle', style: 'background: #d1fae5; color: #065f46; padding: 4px 10px; border-radius: 4px; font-size: 13px;'
            end
          end
          # Queue
          div style: 'display: flex; justify-content: space-between; align-items: center;' do
            span 'Queue', style: 'color: #6b7280;'
            jobs = begin
              Sidekiq::Stats.new.enqueued
            rescue StandardError
              0
            end
            span "#{jobs} jobs", style: 'color: #374151;'
          end
          # Twilio
          div style: 'display: flex; justify-content: space-between; align-items: center;' do
            span 'Twilio', style: 'color: #6b7280;'
            if TwilioCredential.current.present?
              span 'Connected', style: 'background: #d1fae5; color: #065f46; padding: 4px 10px; border-radius: 4px; font-size: 13px;'
            else
              span 'Not configured', style: 'background: #fee2e2; color: #991b1b; padding: 4px 10px; border-radius: 4px; font-size: 13px;'
            end
          end
        end
      end

      # Contact Breakdown Panel
      div style: 'flex: 1; background: #fff; border-radius: 8px; padding: 20px; box-shadow: 0 1px 3px rgba(0,0,0,0.1);' do
        div 'Contact Breakdown', style: 'font-size: 16px; font-weight: 600; color: #1f2937; margin-bottom: 16px;'
        div style: 'display: flex; flex-direction: column; gap: 12px;' do
          div style: 'display: flex; justify-content: space-between; align-items: center;' do
            span 'Businesses', style: 'color: #6b7280;'
            span business_count.to_s, style: 'font-weight: 600; color: #374151;'
          end
          div style: 'display: flex; justify-content: space-between; align-items: center;' do
            span 'Consumers', style: 'color: #6b7280;'
            span consumer_count.to_s, style: 'font-weight: 600; color: #374151;'
          end
          div style: 'display: flex; justify-content: space-between; align-items: center;' do
            span 'High Risk', style: 'color: #6b7280;'
            if high_risk > 0
              span high_risk.to_s, style: 'background: #fee2e2; color: #991b1b; padding: 4px 10px; border-radius: 4px; font-size: 13px; font-weight: 600;'
            else
              span '0', style: 'font-weight: 600; color: #374151;'
            end
          end
        end
      end
    end

    # ========================================
    # Recent Activity
    # ========================================
    recent = Contact.completed.order(lookup_performed_at: :desc).limit(5)
    if recent.any?
      div style: 'background: #fff; border-radius: 8px; padding: 20px; box-shadow: 0 1px 3px rgba(0,0,0,0.1);' do
        div 'Recent Lookups', style: 'font-size: 16px; font-weight: 600; color: #1f2937; margin-bottom: 16px;'
        table style: 'width: 100%; border-collapse: collapse;' do
          thead do
            tr style: 'border-bottom: 1px solid #e5e7eb;' do
              th 'Phone', style: 'text-align: left; padding: 10px 8px; font-weight: 500; color: #6b7280;'
              th 'Carrier', style: 'text-align: left; padding: 10px 8px; font-weight: 500; color: #6b7280;'
              th 'Type', style: 'text-align: left; padding: 10px 8px; font-weight: 500; color: #6b7280;'
              th 'Risk', style: 'text-align: left; padding: 10px 8px; font-weight: 500; color: #6b7280;'
              th 'Time', style: 'text-align: left; padding: 10px 8px; font-weight: 500; color: #6b7280;'
            end
          end
          tbody do
            recent.each do |c|
              tr style: 'border-bottom: 1px solid #f3f4f6;' do
                td c.formatted_phone_number || c.raw_phone_number, style: 'padding: 10px 8px; color: #374151;'
                td c.carrier_name || '-', style: 'padding: 10px 8px; color: #374151;'
                td style: 'padding: 10px 8px;' do
                  if c.device_type
                    span c.device_type, style: 'background: #e0e7ff; color: #4338ca; padding: 3px 8px; border-radius: 4px; font-size: 12px;'
                  else
                    span '-'
                  end
                end
                td style: 'padding: 10px 8px;' do
                  case c.sms_pumping_risk_level
                  when 'high'
                    span 'High', style: 'background: #fee2e2; color: #991b1b; padding: 3px 8px; border-radius: 4px; font-size: 12px;'
                  when 'medium'
                    span 'Med', style: 'background: #fef3c7; color: #92400e; padding: 3px 8px; border-radius: 4px; font-size: 12px;'
                  when 'low'
                    span 'Low', style: 'background: #d1fae5; color: #065f46; padding: 3px 8px; border-radius: 4px; font-size: 12px;'
                  else
                    span '-'
                  end
                end
                td c.lookup_performed_at&.strftime('%b %d, %H:%M') || '-', style: 'padding: 10px 8px; color: #6b7280;'
              end
            end
          end
        end
      end
    end

    # ========================================
    # Chart.js Initialization
    # ========================================
    script do
      raw <<-JS
        document.addEventListener('DOMContentLoaded', function() {
          const colors = {
            primary: '#2563eb',
            success: '#059669',
            warning: '#d97706',
            danger: '#dc2626',
            info: '#6366f1',
            gray: '#9ca3af'
          };

          // Status Distribution Donut
          const statusCtx = document.getElementById('statusChart');
          if (statusCtx) {
            new Chart(statusCtx, {
              type: 'doughnut',
              data: {
                labels: ['Completed', 'Pending', 'Processing', 'Failed'],
                datasets: [{
                  data: [#{completed_count}, #{pending_count}, #{processing_count}, #{failed_count}],
                  backgroundColor: [colors.success, colors.info, colors.primary, colors.danger],
                  borderWidth: 0
                }]
              },
              options: {
                responsive: true,
                maintainAspectRatio: false,
                cutout: '60%',
                plugins: {
                  legend: {
                    position: 'right',
                    labels: { padding: 20, usePointStyle: true, font: { size: 13 } }
                  }
                }
              }
            });
          }

          // Device Type Bar Chart
          const deviceCtx = document.getElementById('deviceChart');
          if (deviceCtx) {
            new Chart(deviceCtx, {
              type: 'bar',
              data: {
                labels: ['Mobile', 'Landline', 'VoIP'],
                datasets: [{
                  data: [#{mobile_count}, #{landline_count}, #{voip_count}],
                  backgroundColor: [colors.primary, colors.info, colors.warning],
                  borderRadius: 6,
                  barThickness: 50
                }]
              },
              options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                  legend: { display: false }
                },
                scales: {
                  y: {
                    beginAtZero: true,
                    grid: { color: '#f3f4f6' },
                    ticks: { font: { size: 12 } }
                  },
                  x: {
                    grid: { display: false },
                    ticks: { font: { size: 12 } }
                  }
                }
              }
            });
          }

          // Top Carriers Bar Chart
          const carrierCtx = document.getElementById('carrierChart');
          if (carrierCtx) {
            new Chart(carrierCtx, {
              type: 'bar',
              data: {
                labels: #{top_carriers.keys.map { |c| c.to_s.truncate(20) }.to_json.html_safe},
                datasets: [{
                  data: #{top_carriers.values.to_json.html_safe},
                  backgroundColor: ['#2563eb', '#059669', '#d97706', '#6366f1', '#dc2626'],
                  borderRadius: 6,
                  barThickness: 30
                }]
              },
              options: {
                responsive: true,
                maintainAspectRatio: false,
                indexAxis: 'y',
                plugins: {
                  legend: { display: false }
                },
                scales: {
                  x: {
                    beginAtZero: true,
                    grid: { color: '#f3f4f6' },
                    ticks: { font: { size: 12 } }
                  },
                  y: {
                    grid: { display: false },
                    ticks: { font: { size: 11 } }
                  }
                }
              }
            });
          }

          // Daily Lookups Line Chart
          const dailyCtx = document.getElementById('dailyChart');
          if (dailyCtx) {
            new Chart(dailyCtx, {
              type: 'line',
              data: {
                labels: #{daily_lookups.map { |d| d[:date] }.to_json.html_safe},
                datasets: [{
                  label: 'Lookups',
                  data: #{daily_lookups.map { |d| d[:count] }.to_json.html_safe},
                  borderColor: colors.primary,
                  backgroundColor: 'rgba(37, 99, 235, 0.1)',
                  fill: true,
                  tension: 0.4,
                  pointBackgroundColor: colors.primary,
                  pointRadius: 5,
                  pointHoverRadius: 7
                }]
              },
              options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                  legend: { display: false }
                },
                scales: {
                  y: {
                    beginAtZero: true,
                    grid: { color: '#f3f4f6' },
                    ticks: { font: { size: 12 } }
                  },
                  x: {
                    grid: { display: false },
                    ticks: { font: { size: 12 } }
                  }
                }
              }
            });
          }
        });
      JS
    end
  end
end
