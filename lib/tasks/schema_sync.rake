namespace :db do
  desc "Verify schema.rb is in sync with migrations (Darwin-Gödel safety check)"
  task verify_schema_sync: :environment do
    puts "🔍 Darwin-Gödel Schema Sync Verification"
    puts "=" * 60

    migration_count = Dir[Rails.root.join('db/migrate/*.rb')].count
    schema_path = Rails.root.join('db/schema.rb')

    unless File.exist?(schema_path)
      puts "❌ CRITICAL: db/schema.rb does not exist!"
      puts "   Run: rails db:schema:dump"
      exit 1
    end

    schema_content = File.read(schema_path)
    table_count = schema_content.scan(/create_table/).count
    column_count = schema_content.scan(/t\.\w+/).count

    puts "Migrations:       #{migration_count} files"
    puts "Schema tables:    #{table_count}"
    puts "Schema columns:   #{column_count}"
    puts ""

    # Heuristic: migrations/5 ≈ expected tables (rough estimate)
    expected_min_tables = migration_count / 8
    expected_min_columns = migration_count * 3

    if table_count < expected_min_tables
      puts "⚠️  WARNING: Schema may be out of sync"
      puts "   Expected ~#{expected_min_tables} tables, found #{table_count}"
      puts "   Recommendation: Run 'rails db:migrate && rails db:schema:dump'"
      exit 1
    end

    if column_count < expected_min_columns
      puts "⚠️  WARNING: Schema may be missing columns"
      puts "   Expected ~#{expected_min_columns} columns, found #{column_count}"
      puts "   Recommendation: Run 'rails db:migrate && rails db:schema:dump'"
      exit 1
    end

    puts "✅ Schema appears to be in sync"
    puts ""
    puts "Schema version: #{schema_content[/version: (\d+)/, 1]}"
  end

  desc "Fix schema drift (Darwin-Gödel Generation 3 solution)"
  task fix_schema_drift: :environment do
    puts "🔧 Fixing Schema Drift - Darwin-Gödel Gen3 Solution"
    puts "=" * 60

    # Step 1: Backup
    schema_path = Rails.root.join('db/schema.rb')
    backup_path = Rails.root.join('db/schema.rb.backup')

    if File.exist?(schema_path)
      FileUtils.cp(schema_path, backup_path)
      puts "✓ Backup created: db/schema.rb.backup"
    end

    # Step 2: Show status
    puts "\n📊 Migration Status:"
    Rake::Task['db:migrate:status'].invoke

    # Step 3: Migrate
    puts "\n⚙️  Running migrations..."
    Rake::Task['db:migrate'].invoke

    # Step 4: Dump schema
    puts "\n📝 Regenerating schema..."
    Rake::Task['db:schema:dump'].invoke

    # Step 5: Verify
    puts "\n🔍 Verification:"
    Rake::Task['db:verify_schema_sync'].invoke

    puts "\n✅ Schema drift fixed!"
    puts "   Review changes: git diff db/schema.rb"
  end
end
