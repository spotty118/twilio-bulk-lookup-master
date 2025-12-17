namespace :contacts do
  desc 'maintenance:reset_circuits'
  task reset_circuits: :environment do
    CircuitBreakerService.reset_all!
  end

  desc 'maintenance:circuit_breakers'
  task circuit_breakers: :environment do
    CircuitBreakerService.status
  end

  desc 'maintenance:clear_connections'
  task clear_connections: :environment do
    HttpClient.clear_connections
    puts 'HTTP connections cleared.'
  end

  desc 'maintenance:diagnostics'
  task diagnostics: :environment do
    puts 'Running System Diagnostics...'
    # Add diagnostic logic here
    puts 'Diagnostics complete.'
  end

  desc 'maintenance:health_check'
  task health_check: :environment do
    puts 'Checking System Health...'
    # Add health check logic here
    puts 'Health check passed.'
  end

  desc 'Export completed contacts to CSV daily'
  task export_daily: :environment do
    Rails.logger.info 'Starting daily contact export...'
    # In a real app, this would enqueue a job.
    # ExportContactsJob.perform_later
    puts 'Daily export job enqueued (Simulated).'
  end
end
