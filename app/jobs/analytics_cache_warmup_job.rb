# frozen_string_literal: true

class AnalyticsCacheWarmupJob < ApplicationJob
  queue_as :low_priority

  def perform(user_id, start_date, end_date)
    user = User.find(user_id)

    # Create a temporary controller instance for cache generation
    controller = AnalyticsController.new
    controller.instance_variable_set(:@current_user, user)
    controller.instance_variable_set(:@start_date, start_date)
    controller.instance_variable_set(:@end_date, end_date)

    # Warm up critical caches
    warmup_methods = [
      :calculate_overview_metrics,
      :fetch_performance_data,
      :calculate_conversion_funnel,
      :fetch_top_performers,
      :analyze_keyword_performance,
      :calculate_trends
    ]

    warmup_methods.each do |method|
      begin
        Rails.cache.fetch(
          cache_key_for(user_id, start_date, end_date, method),
          expires_in: 30.minutes
        ) do
          controller.send(method) if controller.respond_to?(method, true)
        end
      rescue StandardError => e
        Rails.logger.error "Cache warmup failed for #{method}: #{e.message}"
      end
    end

    Rails.logger.info "Analytics cache warmed up for user #{user_id}"
  end

  private

  def cache_key_for(user_id, start_date, end_date, method)
    key_parts = [
      "analytics",
      method.to_s,
      user_id,
      start_date&.to_s,
      end_date&.to_s
    ].compact

    Digest::SHA256.hexdigest(key_parts.join("-"))
  end
end
