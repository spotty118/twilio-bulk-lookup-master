# StatusManageable Concern
# Provides status tracking and workflow management

module StatusManageable
  extend ActiveSupport::Concern
  
  included do
    # Status change callbacks
    before_save :track_status_change, if: :status_changed?
    after_commit :log_status_change, if: :saved_change_to_status?
  end
  
  class_methods do
    # Get status distribution
    def status_distribution
      group(:status).count
    end
    
    # Get status percentages
    def status_percentages
      total = count.to_f
      return {} if total == 0
      
      group(:status).count.transform_values do |count|
        (count / total * 100).round(2)
      end
    end
    
    # Get contacts that need attention
    def needs_attention
      where(status: ['pending', 'failed'])
    end
    
    # Get contacts in progress
    def in_progress
      where(status: 'processing')
    end
    
    # Get completed work
    def finished
      where(status: ['completed', 'failed'])
    end
    
    # Get success rate
    def success_rate
      finished_count = finished.count
      return 0 if finished_count == 0
      
      completed = where(status: 'completed').count
      (completed.to_f / finished_count * 100).round(2)
    end
    
    # Get average processing time
    def average_processing_time
      where.not(lookup_performed_at: nil)
           .average("EXTRACT(EPOCH FROM (lookup_performed_at - created_at))")
           &.to_f
           &.round(2)
    end
    
    # Get stuck records (in processing for too long)
    def stuck_in_processing(threshold = 1.hour)
      processing.where('updated_at < ?', threshold.ago)
    end
  end
  
  # Instance methods
  def status_valid_transition?(new_status)
    case status
    when 'pending'
      ['processing', 'failed'].include?(new_status)
    when 'processing'
      ['completed', 'failed'].include?(new_status)
    when 'completed'
      false  # Terminal state
    when 'failed'
      ['pending', 'processing'].include?(new_status)  # Allow retry
    else
      true  # Unknown state, allow transition
    end
  end
  
  def can_transition_to?(new_status)
    status_valid_transition?(new_status)
  end
  
  def processing_time
    return nil unless lookup_performed_at && created_at
    
    (lookup_performed_at - created_at).to_f
  end
  
  def processing_time_humanized
    return 'N/A' unless processing_time
    
    seconds = processing_time
    
    if seconds < 60
      "#{seconds.round(1)}s"
    elsif seconds < 3600
      minutes = (seconds / 60).round(1)
      "#{minutes}m"
    else
      hours = (seconds / 3600).round(1)
      "#{hours}h"
    end
  end
  
  def is_stuck?
    status == 'processing' && updated_at < 1.hour.ago
  end
  
  def is_terminal_state?
    status == 'completed'
  end
  
  def is_retryable_state?
    status == 'failed' || status == 'pending'
  end
  
  def status_badge_class
    case status
    when 'completed'
      'success'
    when 'processing'
      'warning'
    when 'failed'
      'error'
    when 'pending'
      'info'
    else
      'default'
    end
  end
  
  private

  def track_status_change
    if status_changed? && status_was.present? && !status_valid_transition?(status)
      error_message = "Invalid status transition: #{status_was} -> #{status}"
      Rails.logger.error("#{self.class.name} ##{id}: #{error_message}")
      errors.add(:status, error_message)
      # Restore previous status
      self.status = status_was
      throw :abort
    end
  end
  
  def log_status_change
    old_status = saved_change_to_status[0]
    new_status = saved_change_to_status[1]
    
    Rails.logger.info("#{self.class.name} ##{id} status changed: #{old_status} -> #{new_status}")
  end
end

