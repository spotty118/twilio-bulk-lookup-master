class AddPerformanceIndices < ActiveRecord::Migration[7.2]
  def up
    # Composite index for job queue polling
    # Query pattern: Contact.where(status: 'pending').order(created_at: :asc).limit(100)
    # Found in: app/jobs/lookup_request_job.rb and background job polling
    # This index supports efficient queue-based job processing with FIFO ordering
    add_index :contacts, [:status, :created_at],
              name: 'index_contacts_on_status_and_created_at',
              if_not_exists: true

    # Partial index for business enrichment filtering
    # Query pattern: Contact.where(business_enriched: false, status: 'completed')
    # Found in: app/jobs/business_enrichment_job.rb for identifying enrichment candidates
    # This partial index only indexes rows requiring enrichment, reducing index size
    add_index :contacts, [:business_enriched, :status],
              where: "business_enriched = false",
              name: 'idx_contacts_be_false_status',
              if_not_exists: true

    # Partial index for low quality score filtering
    # Query pattern: Contact.where('quality_score < ?', 60).where(status: 'completed')
    # Found in: app/admin/contacts.rb for quality filtering and dashboard analytics
    # This partial index targets quality improvement workflows by only indexing low-quality records
    add_index :contacts, [:data_quality_score, :status],
              where: "data_quality_score < 60",
              name: 'idx_contacts_qs_lt60_status',
              if_not_exists: true
  end

  def down
    remove_index :contacts, name: 'index_contacts_on_status_and_created_at', if_exists: true
    remove_index :contacts, name: 'idx_contacts_be_false_status', if_exists: true
    remove_index :contacts, name: 'idx_contacts_qs_lt60_status', if_exists: true
  end
end
