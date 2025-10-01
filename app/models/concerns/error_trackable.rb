# ErrorTrackable Concern
# Adds error tracking and analytics capabilities to models

module ErrorTrackable
  extend ActiveSupport::Concern
  
  included do
    # Track error patterns
    scope :with_errors, -> { where.not(error_code: nil) }
    scope :without_errors, -> { where(error_code: nil) }
  end
  
  class_methods do
    # Get error statistics
    def error_stats
      with_errors.group(:error_code).count.sort_by { |_, count| -count }
    end
    
    # Get most common errors (top N)
    def top_errors(limit = 10)
      error_stats.take(limit)
    end
    
    # Get error rate
    def error_rate
      total = count
      return 0 if total == 0
      
      errors = with_errors.count
      (errors.to_f / total * 100).round(2)
    end
    
    # Group errors by category
    def errors_by_category
      categories = {
        invalid_format: [],
        not_found: [],
        authentication: [],
        rate_limit: [],
        network: [],
        other: []
      }
      
      with_errors.pluck(:error_code).each do |error|
        next if error.blank?
        
        case error.downcase
        when /invalid|format|malformed/
          categories[:invalid_format] << error
        when /not found|does not exist/
          categories[:not_found] << error
        when /auth|permission|unauthorized/
          categories[:authentication] << error
        when /rate limit|too many/
          categories[:rate_limit] << error
        when /network|timeout|connection/
          categories[:network] << error
        else
          categories[:other] << error
        end
      end
      
      # Return with counts
      categories.transform_values(&:size).select { |_, count| count > 0 }
    end
  end
  
  # Instance methods
  def has_error?
    error_code.present?
  end
  
  def error_category
    return nil unless has_error?
    
    case error_code.downcase
    when /invalid|format|malformed/
      :invalid_format
    when /not found|does not exist/
      :not_found
    when /auth|permission|unauthorized/
      :authentication
    when /rate limit|too many/
      :rate_limit
    when /network|timeout|connection/
      :network
    else
      :other
    end
  end
  
  def error_severity
    return :none unless has_error?
    
    case error_category
    when :authentication, :rate_limit
      :critical
    when :invalid_format, :not_found
      :low
    when :network
      :medium
    else
      :medium
    end
  end
  
  def error_recoverable?
    return false unless has_error?
    
    case error_category
    when :network, :rate_limit
      true
    when :invalid_format, :not_found, :authentication
      false
    else
      false  # Conservative: don't retry unknown errors
    end
  end
end

