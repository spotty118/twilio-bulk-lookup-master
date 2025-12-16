namespace :contacts do
  desc 'Export all completed contacts to CSV'
  task export_completed: :environment do
    require 'csv'

    filename = "contacts_export_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv"
    filepath = Rails.root.join('tmp', filename)

    puts "Exporting completed contacts to #{filename}..."

    CSV.open(filepath, 'w') do |csv|
      # Header row
      csv << [
        'ID',
        'Raw Phone Number',
        'Formatted Phone Number',
        'Status',
        'Carrier Name',
        'Device Type',
        'Mobile Country Code',
        'Mobile Network Code',
        'Error Code',
        'Lookup Performed At',
        'Created At',
        'Updated At'
      ]

      # Data rows
      Contact.completed.find_each do |contact|
        csv << [
          contact.id,
          contact.raw_phone_number,
          contact.formatted_phone_number,
          contact.status,
          contact.carrier_name,
          contact.device_type,
          contact.mobile_country_code,
          contact.mobile_network_code,
          contact.error_code,
          contact.lookup_performed_at&.iso8601,
          contact.created_at.iso8601,
          contact.updated_at.iso8601
        ]
      end
    end

    puts "✅ Export complete! File saved to: #{filepath}"
    puts "   Total records exported: #{Contact.completed.count}"
  end

  desc 'Reprocess all failed contacts'
  task reprocess_failed: :environment do
    failed_contacts = Contact.failed
    count = failed_contacts.count

    if count == 0
      puts 'No failed contacts to reprocess.'
      exit
    end

    puts "Found #{count} failed contacts to reprocess..."

    queued = 0
    failed_contacts.find_each do |contact|
      if contact.retriable?
        contact.update(status: 'pending')
        LookupRequestJob.perform_later(contact)
        queued += 1
      else
        puts "  Skipping contact #{contact.id} - permanent failure"
      end
    end

    puts "✅ Queued #{queued} contacts for reprocessing"
    puts "   Skipped #{count - queued} contacts (permanent failures)"
  end

  desc 'Clean up old processed contacts (older than specified days)'
  task :cleanup, [:days] => :environment do |_t, args|
    days = (args[:days] || 90).to_i
    cutoff_date = days.days.ago

    puts "Cleaning up contacts older than #{days} days (before #{cutoff_date.strftime('%Y-%m-%d')})..."

    old_contacts = Contact.where('lookup_performed_at < ? OR (created_at < ? AND status = ?)',
                                 cutoff_date, cutoff_date, 'completed')
    count = old_contacts.count

    if count == 0
      puts 'No contacts to clean up.'
      exit
    end

    print "This will delete #{count} contacts. Continue? (y/N): "
    response = STDIN.gets.chomp.downcase

    if %w[y yes].include?(response)
      old_contacts.delete_all
      puts "✅ Deleted #{count} old contacts"
    else
      puts '❌ Cleanup cancelled'
    end
  end

  desc 'Show contact statistics'
  task stats: :environment do
    total = Contact.count
    pending = Contact.pending.count
    processing = Contact.processing.count
    completed = Contact.completed.count
    failed = Contact.failed.count

    completion_rate = total > 0 ? (completed.to_f / total * 100).round(2) : 0

    puts "\n" + '=' * 60
    puts 'CONTACT STATISTICS'
    puts '=' * 60
    puts
    puts "Total Contacts:       #{total.to_s.rjust(10)}"
    puts "  Pending:            #{pending.to_s.rjust(10)}"
    puts "  Processing:         #{processing.to_s.rjust(10)}"
    puts "  Completed:          #{completed.to_s.rjust(10)}"
    puts "  Failed:             #{failed.to_s.rjust(10)}"
    puts
    puts "Completion Rate:      #{completion_rate.to_s.rjust(9)}%"
    puts

    if completed > 0
      puts '-' * 60
      puts 'DEVICE TYPE BREAKDOWN'
      puts '-' * 60

      Contact.completed.group(:device_type).count.each do |device_type, count|
        percentage = (count.to_f / completed * 100).round(2)
        puts "  #{(device_type || 'Unknown').ljust(20)} #{count.to_s.rjust(8)} (#{percentage}%)"
      end
      puts

      puts '-' * 60
      puts 'TOP 10 CARRIERS'
      puts '-' * 60

      Contact.completed.where.not(carrier_name: nil)
             .group(:carrier_name)
             .count
             .sort_by { |_, count| -count }
             .take(10)
             .each_with_index do |(carrier, count), index|
        percentage = (count.to_f / completed * 100).round(2)
        puts "  #{(index + 1).to_s.rjust(2)}. #{carrier.ljust(30)} #{count.to_s.rjust(6)} (#{percentage}%)"
      end
      puts
    end

    if failed > 0
      puts '-' * 60
      puts 'FAILURE ANALYSIS'
      puts '-' * 60

      retriable = Contact.failed.select(&:retriable?).count
      permanent = failed - retriable

      puts "  Retriable Failures: #{retriable.to_s.rjust(10)}"
      puts "  Permanent Failures: #{permanent.to_s.rjust(10)}"
      puts

      puts '  Top Error Messages:'
      Contact.failed.where.not(error_code: nil)
             .group(:error_code)
             .count
             .sort_by { |_, count| -count }
             .take(5)
             .each do |error, count|
        puts "    • #{error[0..50]}... (#{count})"
      end
      puts
    end

    puts '=' * 60
    puts
  end

  desc 'Validate all pending contacts before processing'
  task validate_pending: :environment do
    puts 'Validating pending contacts...'

    invalid_count = 0
    Contact.pending.find_each do |contact|
      unless contact.raw_phone_number.match?(/\A\+?[1-9]\d{1,14}\z/)
        puts "  ❌ Invalid: #{contact.id} - #{contact.raw_phone_number}"
        contact.mark_failed!('Invalid phone number format')
        invalid_count += 1
      end
    end

    if invalid_count == 0
      puts '✅ All pending contacts have valid phone numbers'
    else
      puts "⚠️  Marked #{invalid_count} contacts as failed due to invalid format"
    end
  end

  desc 'Queue all pending contacts for processing'
  task process_pending: :environment do
    pending_contacts = Contact.pending
    count = pending_contacts.count

    if count == 0
      puts 'No pending contacts to process.'
      exit
    end

    puts "Queuing #{count} pending contacts for processing..."

    pending_contacts.find_each do |contact|
      LookupRequestJob.perform_later(contact)
    end

    puts "✅ Queued #{count} contacts for processing"
    puts '   Monitor progress at: http://localhost:3000/sidekiq'
  end

  desc 'Reset stuck processing contacts (older than 1 hour)'
  task reset_stuck: :environment do
    stuck_contacts = Contact.processing.where('updated_at < ?', 1.hour.ago)
    count = stuck_contacts.count

    if count == 0
      puts 'No stuck contacts found.'
      exit
    end

    puts "Found #{count} contacts stuck in 'processing' state..."

    stuck_contacts.update_all(status: 'pending')

    puts "✅ Reset #{count} stuck contacts to 'pending'"
    puts '   You can now reprocess them with: rake contacts:process_pending'
  end
end

namespace :twilio do
  desc 'Test Twilio credentials'
  task test_credentials: :environment do
    credentials = TwilioCredential.current

    unless credentials
      puts '❌ No Twilio credentials configured'
      puts '   Configure them at: http://localhost:3000/admin/twilio_credentials'
      exit 1
    end

    puts 'Testing Twilio credentials...'
    puts "  Account SID: #{credentials.account_sid[0..5]}***#{credentials.account_sid[-4..]}"

    begin
      client = Twilio::REST::Client.new(credentials.account_sid, credentials.auth_token)
      account = client.api.accounts(credentials.account_sid).fetch

      puts '✅ Credentials are valid!'
      puts "   Account Name: #{account.friendly_name}"
      puts "   Account Status: #{account.status}"
      puts "   Account Type: #{account.type}"
    rescue Twilio::REST::RestError => e
      puts '❌ Credential test failed'
      puts "   Error: #{e.message}"
      exit 1
    rescue StandardError => e
      puts '❌ Connection error'
      puts "   Error: #{e.message}"
      exit 1
    end
  end

  desc 'Clear credentials cache'
  task clear_cache: :environment do
    Rails.cache.delete('twilio_credentials')
    puts '✅ Cleared Twilio credentials cache'
  end
end

namespace :maintenance do
  desc 'Run database maintenance tasks'
  task database: :environment do
    puts 'Running database maintenance...'

    # Analyze tables for better query planning
    puts '  Analyzing tables...'
    ActiveRecord::Base.connection.execute('ANALYZE contacts')
    ActiveRecord::Base.connection.execute('ANALYZE twilio_credentials')
    ActiveRecord::Base.connection.execute('ANALYZE admin_users')

    # Vacuum to reclaim space (use VACUUM ANALYZE on production with caution)
    if Rails.env.development?
      puts '  Vacuuming database...'
      ActiveRecord::Base.connection.execute('VACUUM ANALYZE')
    end

    puts '✅ Database maintenance complete'
  end

  desc 'Show system information'
  task info: :environment do
    puts "\n" + '=' * 60
    puts 'SYSTEM INFORMATION'
    puts '=' * 60
    puts
    puts "Environment:          #{Rails.env}"
    puts "Rails Version:        #{Rails.version}"
    puts "Ruby Version:         #{RUBY_VERSION}"
    puts "App Version:          #{HttpClient::APP_VERSION}"
    puts "Database:             #{ActiveRecord::Base.connection.adapter_name}"
    puts
    puts "Total Contacts:       #{Contact.count}"
    puts "Total Admin Users:    #{AdminUser.count}"
    puts "Twilio Configured:    #{TwilioCredential.current.present? ? 'Yes' : 'No'}"
    puts

    # Redis check
    begin
      redis = Redis.new
      if redis.ping == 'PONG'
        puts 'Redis Status:         ✅ Connected'
        puts "Redis Version:        #{redis.info['redis_version']}"
      end
    rescue StandardError => e
      puts "Redis Status:         ❌ Error: #{e.message}"
    end

    puts
    puts '=' * 60
    puts
  end

  desc 'Show circuit breaker status'
  task circuit_breakers: :environment do
    puts "\n" + '=' * 60
    puts 'CIRCUIT BREAKER STATUS'
    puts '=' * 60
    puts

    if defined?(CircuitBreakerService)
      states = CircuitBreakerService.all_states

      states.each do |name, data|
        status_icon = case data[:state]
                      when :closed then '🟢'
                      when :half_open then '🟡'
                      when :open then '🔴'
                      else '⚪'
                      end

        puts "#{status_icon} #{name.to_s.ljust(20)} #{data[:state].to_s.upcase}"
        puts "   Failures: #{data[:failures] || 0}/#{data[:threshold]}"
        puts "   Description: #{data[:description]}"
        puts
      end

      open_count = states.count { |_, d| d[:state] == :open }
      puts '-' * 60
      puts "Total Services: #{states.count}"
      puts "Open Circuits:  #{open_count}"
      puts "Health:         #{open_count.zero? ? '✅ All Healthy' : '⚠️  Degraded'}"
    else
      puts 'CircuitBreakerService not loaded'
    end

    puts
    puts '=' * 60
    puts
  end

  desc 'Reset all circuit breakers'
  task reset_circuits: :environment do
    if defined?(CircuitBreakerService)
      puts 'Resetting all circuit breakers...'

      CircuitBreakerService::SERVICES.keys.each do |name|
        CircuitBreakerService.reset(name)
        puts "  ✅ Reset #{name}"
      end

      puts "\n✅ All circuit breakers reset"
    else
      puts 'CircuitBreakerService not loaded'
    end
  end

  desc 'Clear HTTP connection pool'
  task clear_connections: :environment do
    puts 'Clearing HTTP connection pool...'
    HttpClient.clear_connections!
    puts '✅ Connection pool cleared'
  end

  desc 'Run health check'
  task health_check: :environment do
    puts "\n" + '=' * 60
    puts 'HEALTH CHECK'
    puts '=' * 60
    puts

    # Database
    print 'Database:       '
    begin
      ActiveRecord::Base.connection.execute('SELECT 1')
      puts '✅ OK'
    rescue StandardError => e
      puts "❌ #{e.message}"
    end

    # Redis
    print 'Redis:          '
    begin
      redis = Redis.new(url: AppConfig.redis_url)
      redis.ping
      puts '✅ OK'
      redis.close
    rescue StandardError => e
      puts "❌ #{e.message}"
    end

    # Sidekiq
    print 'Sidekiq:        '
    begin
      require 'sidekiq/api'
      stats = Sidekiq::Stats.new
      if stats.processes_size > 0
        puts "✅ OK (#{stats.processes_size} processes)"
      else
        puts '⚠️  No workers running'
      end
    rescue StandardError => e
      puts "❌ #{e.message}"
    end

    # Twilio
    print 'Twilio:         '
    if TwilioCredential.current.present?
      puts '✅ Configured'
    else
      puts '⚠️  Not configured'
    end

    # Sentry
    print 'Sentry:         '
    if defined?(Sentry) && Sentry.configuration.dsn.present?
      puts '✅ Configured'
    else
      puts '⚠️  Not configured'
    end

    puts
    puts '=' * 60
    puts
  end

  desc 'Clear all caches'
  task clear_cache: :environment do
    puts 'Clearing caches...'

    Rails.cache.clear
    puts '  ✅ Rails cache cleared'

    Rails.cache.delete('twilio_credentials')
    puts '  ✅ Twilio credentials cache cleared'

    HttpClient.clear_connections! if defined?(HttpClient)
    puts '  ✅ HTTP connection pool cleared'

    puts "\n✅ All caches cleared"
  end

  desc 'Full system diagnostics'
  task diagnostics: %i[info health_check circuit_breakers] do
    puts "\n✅ Diagnostics complete"
  end
end
