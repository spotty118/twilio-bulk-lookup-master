class VerizonProbabilityService
  attr_reader :contact

  def initialize(contact)
    @contact = contact
  end

  # Calculate both 5G and LTE probabilities
  # Returns hash with five_g, lte, and tower_data
  def calculate_probabilities
    unless contact.latitude.present? && contact.longitude.present?
      Rails.logger.warn "[VerizonProbability] Contact ##{contact.id} missing coordinates"
      return nil
    end

    begin
      # Fetch nearby towers within 15km
      cell_service = OpenCellIdService.new(contact.latitude, contact.longitude)
      all_towers = cell_service.fetch_nearby_towers('all', 15)

      # Separate by technology
      five_g_towers = all_towers.select { |t| t[:radio] == 'NR' }
      lte_towers = all_towers.select { |t| t[:radio] == 'LTE' }

      # Calculate probabilities
      five_g_prob = calculate_technology_probability(five_g_towers, :five_g)
      lte_prob = calculate_technology_probability(lte_towers, :lte)

      # Prepare tower data for storage
      tower_data = {
        five_g_towers: five_g_towers,
        lte_towers: lte_towers,
        nearest_5g_distance: five_g_towers.first&.dig(:distance),
        nearest_lte_distance: lte_towers.first&.dig(:distance)
      }

      {
        five_g: five_g_prob,
        lte: lte_prob,
        tower_data: tower_data
      }
    rescue StandardError => e
      Rails.logger.error "[VerizonProbability] Error calculating probabilities: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      # Fallback to boolean-based probability
      fallback_probability
    end
  end

  # Check if probability needs recalculation
  def needs_recalculation?
    return true if contact.verizon_5g_probability.nil? || contact.verizon_lte_probability.nil?

    # Check if calculation is older than 7 days
    calc_timestamp = contact.verizon_coverage_data&.dig('probability_calculated_at')
    return true unless calc_timestamp

    begin
      calc_time = Time.zone.parse(calc_timestamp)
      calc_time < 7.days.ago
    rescue StandardError
      true
    end
  end

  private

  # Calculate probability for a specific technology (5G or LTE)
  def calculate_technology_probability(towers, technology)
    return 0 if towers.empty?

    nearest_tower = towers.first
    nearest_distance = nearest_tower[:distance]
    tower_count_nearby = towers.count { |t| t[:distance] <= 5.0 }

    # Determine coverage radius
    coverage_radius = estimate_coverage_radius(nearest_tower, tower_count_nearby, technology)

    # Calculate probability based on distance
    calculate_probability_from_distance(nearest_distance, coverage_radius, tower_count_nearby)
  end

  # Estimate coverage radius based on tower data and density
  def estimate_coverage_radius(tower, tower_count, technology)
    # If tower has explicit range, use that (convert meters to km)
    return tower[:range] / 1000.0 if tower[:range].present? && tower[:range] > 0

    # Estimate based on tower density
    if technology == :five_g
      # 5G has shorter range
      case tower_count
      when 5..Float::INFINITY then 2.0  # Dense urban
      when 2..4 then 1.5                # Urban
      else 1.0                           # Suburban/rural
      end
    else
      # LTE has longer range
      case tower_count
      when 5..Float::INFINITY then 10.0 # Dense
      when 2..4 then 7.0                # Urban
      else 5.0                           # Rural
      end
    end
  end

  # Calculate probability based on distance from tower
  def calculate_probability_from_distance(distance, coverage_radius, tower_count)
    # Very close: 95-100%
    if distance <= coverage_radius * 0.5
      return rand(95..100)
    end

    # Within coverage radius: 70-94%
    if distance <= coverage_radius
      ratio = distance / coverage_radius
      # Linear interpolation from 94 down to 70
      return (94 - (ratio * 24)).round
    end

    # Within 1.5x coverage radius: 30-69%
    if distance <= coverage_radius * 1.5
      ratio = (distance - coverage_radius) / (coverage_radius * 0.5)
      # Linear interpolation from 69 down to 30
      return (69 - (ratio * 39)).round
    end

    # Within 2x coverage radius: 10-29%
    if distance <= coverage_radius * 2.0
      ratio = (distance - coverage_radius * 1.5) / (coverage_radius * 0.5)
      # Linear interpolation from 29 down to 10
      return (29 - (ratio * 19)).round
    end

    # Beyond 2x coverage: 0-9% based on tower count
    if tower_count >= 3
      return rand(5..9)
    elsif tower_count >= 1
      return rand(1..4)
    else
      return 0
    end
  end

  # Fallback to boolean-based probability when API fails
  def fallback_probability
    Rails.logger.info "[VerizonProbability] Using fallback probability for contact ##{contact.id}"

    five_g_prob = if contact.verizon_5g_home_available == true
                    75
                  elsif contact.verizon_5g_home_available == false
                    25
                  else
                    nil
                  end

    lte_prob = if contact.verizon_lte_home_available == true
                 75
               elsif contact.verizon_lte_home_available == false
                 25
               else
                 nil
               end

    {
      five_g: five_g_prob,
      lte: lte_prob,
      tower_data: {
        fallback: true,
        probability_method: 'fallback_from_boolean'
      }
    }
  end
end
