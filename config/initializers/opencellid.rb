# OpenCellID API Configuration
OpenCellId = {
  api_key: ENV['OPENCELLID_API_KEY'],
  base_url: 'https://opencellid.org',
  timeout: 10, # seconds
  max_retries: 2
}.freeze

# Validate API key presence
if Rails.env.production? && OpenCellId[:api_key].blank?
  Rails.logger.warn '[OpenCellID] API key not configured. Verizon probability calculation will be disabled.'
end
