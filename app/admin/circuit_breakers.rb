# frozen_string_literal: true

ActiveAdmin.register_page 'Circuit Breakers' do
  menu parent: 'System', priority: 2, label: 'Circuit Breakers'

  content title: 'Circuit Breaker Dashboard' do
    panel 'Circuit Breaker Status - External API Protection' do
      para 'Real-time monitoring of circuit breaker states for all external APIs. ' \
           'Circuit breakers prevent cascade failures by temporarily disabling failing services.'

      # Get all circuit states
      states = CircuitBreakerService.all_states

      # Summary statistics
      total_services = states.count
      open_circuits = states.count { |_, data| data[:state] == :open }
      half_open_circuits = states.count { |_, data| data[:state] == :half_open }
      closed_circuits = states.count { |_, data| data[:state] == :closed }

      # Summary panel
      columns do
        column do
          panel 'Closed (Healthy)', class: 'panel-success' do
            div style: 'text-align: center; padding: 20px;' do
              h2 closed_circuits, style: 'color: green; font-size: 3em; margin: 0;'
              para "#{(closed_circuits.to_f / total_services * 100).round}% operational"
            end
          end
        end

        column do
          panel 'Half-Open (Testing)', class: 'panel-warning' do
            div style: 'text-align: center; padding: 20px;' do
              h2 half_open_circuits, style: 'color: orange; font-size: 3em; margin: 0;'
              para 'Recovery in progress'
            end
          end
        end

        column do
          panel 'Open (Failing)', class: 'panel-danger' do
            div style: 'text-align: center; padding: 20px;' do
              h2 open_circuits, style: 'color: red; font-size: 3em; margin: 0;'
              para open_circuits > 0 ? '⚠️ Attention needed' : 'All services healthy'
            end
          end
        end
      end

      # Detailed circuit status table
      table_for(states.sort_by { |name, data| [data[:state] == :open ? 0 : 1, name.to_s] }) do
        column 'Service' do |item|
          service_name, data = item
          div do
            strong service_name.to_s.titleize
            br
            span data[:description], style: 'font-size: 0.9em; color: gray;'
          end
        end

        column 'State' do |item|
          _, data = item
          state = data[:state]
          _color = data[:color]

          case state
          when :closed
            status_tag '✅ Closed (Healthy)', class: 'ok'
          when :half_open
            status_tag '⚠️ Half-Open (Testing)', class: 'warning'
          when :open
            status_tag '❌ Open (Failing)', class: 'error'
          else
            status_tag 'UNKNOWN', class: 'default'
          end
        end

        column 'Failures' do |item|
          _, data = item
          failures_data = data[:failures] || []
          failures = failures_data.is_a?(Array) ? failures_data.size : failures_data.to_i
          threshold = data[:threshold]

          if failures.zero?
            span '0', style: 'color: green; font-weight: bold;'
          elsif failures >= threshold
            span "#{failures}/#{threshold}", style: 'color: red; font-weight: bold;'
          else
            span "#{failures}/#{threshold}", style: 'color: orange; font-weight: bold;'
          end
        end

        column 'Threshold / Timeout' do |item|
          _, data = item
          div do
            span "Threshold: #{data[:threshold]} failures"
            br
            span "Timeout: #{data[:timeout]}s"
          end
        end

        column 'Actions' do |item|
          service_name, _data = item

          link_to 'Reset Circuit',
                  admin_circuit_breakers_reset_circuit_breaker_path(service: service_name),
                  method: :post,
                  class: 'button',
                  data: { confirm: "Reset circuit breaker for #{service_name}?" }
        end
      end
    end

    # Circuit Breaker Explanation
    panel 'Circuit Breaker States Explained' do
      columns do
        column do
          panel 'Closed (Normal)' do
            para '✅ API is healthy. All requests are allowed through.'
            para 'Failures: < threshold'
          end
        end

        column do
          panel 'Half-Open (Testing)' do
            para '⚠️ Circuit is testing if API recovered. Limited requests allowed.'
            para 'After timeout period, allows test requests to check if service is back.'
          end
        end

        column do
          panel 'Open (Failed)' do
            para '❌ API is failing. All requests are blocked (fail fast).'
            para 'Failures: >= threshold. Will re-test after timeout period.'
          end
        end
      end
    end

    # Recent activity (if logging is configured)
    panel 'Configuration' do
      table_for(CircuitBreakerService::SERVICES.sort_by { |name, _| name.to_s }) do
        column 'Service' do |item|
          service_name, = item
          strong service_name.to_s.titleize
        end

        column 'Description' do |item|
          _, config = item
          config[:description]
        end

        column 'Threshold' do |item|
          _, config = item
          "#{config[:threshold]} failures"
        end

        column 'Timeout' do |item|
          _, config = item
          "#{config[:timeout]} seconds"
        end
      end
    end
  end

  # Action to reset a circuit
  page_action :reset_circuit_breaker, method: :post do
    service_name = params[:service]&.to_sym

    if CircuitBreakerService.reset(service_name)
      redirect_to admin_circuit_breakers_path, notice: "Circuit breaker for #{service_name} has been reset."
    else
      redirect_to admin_circuit_breakers_path, alert: "Failed to reset circuit breaker for #{service_name}."
    end
  end
end
