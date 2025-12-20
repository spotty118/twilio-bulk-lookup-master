# frozen_string_literal: true

class RemoveDashboardStatsRefreshTrigger < ActiveRecord::Migration[7.2]
  def up
    execute 'DROP TRIGGER IF EXISTS trigger_dashboard_stats_refresh ON contacts;'
    execute 'DROP FUNCTION IF EXISTS refresh_dashboard_stats();'
  end

  def down
    # No-op: trigger/function were removed to prevent transaction errors.
  end
end
