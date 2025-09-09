# frozen_string_literal: true

module AnalyticsCacheable
  extend ActiveSupport::Concern

  included do
    # Cache configuration
    CACHE_EXPIRY = {
      short: 5.minutes,
      medium: 30.minutes,
      long: 2.hours,
      daily: 24.hours
    }.freeze
  end

  private

  # Generate cache key based on user, date range, and filters
  def analytics_cache_key(prefix, params = {})
    key_parts = [
      "analytics",
      prefix,
      current_user.id,
      @start_date&.to_s,
      @end_date&.to_s,
      params.sort.to_h.to_s
    ].compact

    Digest::SHA256.hexdigest(key_parts.join("-"))
  end

  # Cache overview metrics with medium expiry
  def cached_overview_metrics
    Rails.cache.fetch(analytics_cache_key("overview_metrics"), expires_in: CACHE_EXPIRY[:medium]) do
      calculate_overview_metrics
    end
  end

  # Cache performance data with short expiry
  def cached_performance_data
    Rails.cache.fetch(analytics_cache_key("performance_data"), expires_in: CACHE_EXPIRY[:short]) do
      fetch_performance_data
    end
  end

  # Cache conversion funnel with medium expiry
  def cached_conversion_funnel
    Rails.cache.fetch(analytics_cache_key("conversion_funnel"), expires_in: CACHE_EXPIRY[:medium]) do
      calculate_conversion_funnel
    end
  end

  # Cache time series data with longer expiry for historical data
  def cached_time_series_data(period = :daily)
    cache_duration = period == :hourly ? CACHE_EXPIRY[:short] : CACHE_EXPIRY[:long]

    Rails.cache.fetch(analytics_cache_key("time_series", period: period), expires_in: cache_duration) do
      fetch_time_series_data(period)
    end
  end

  # Cache keyword performance with medium expiry
  def cached_keyword_performance
    Rails.cache.fetch(analytics_cache_key("keyword_performance"), expires_in: CACHE_EXPIRY[:medium]) do
      analyze_keyword_performance
    end
  end

  # Cache lead analytics with short expiry
  def cached_lead_analytics
    Rails.cache.fetch(analytics_cache_key("lead_analytics"), expires_in: CACHE_EXPIRY[:short]) do
      analyze_lead_data
    end
  end

  # Cache trend data with long expiry
  def cached_trend_data
    Rails.cache.fetch(analytics_cache_key("trend_data"), expires_in: CACHE_EXPIRY[:long]) do
      calculate_trends
    end
  end

  # Cache predictions with daily expiry
  def cached_predictions
    Rails.cache.fetch(analytics_cache_key("predictions"), expires_in: CACHE_EXPIRY[:daily]) do
      generate_predictions
    end
  end

  # Cache comparative metrics with medium expiry
  def cached_comparative_metrics
    Rails.cache.fetch(analytics_cache_key("comparative"), expires_in: CACHE_EXPIRY[:medium]) do
      calculate_comparative_metrics
    end
  end

  # Cache ROI analysis with long expiry
  def cached_roi_analysis
    Rails.cache.fetch(analytics_cache_key("roi_analysis"), expires_in: CACHE_EXPIRY[:long]) do
      calculate_roi_by_source
    end
  end

  # Clear all analytics caches for the current user
  def clear_analytics_cache!
    Rails.cache.delete_matched("analytics_*_#{current_user.id}_*")
  end

  # Clear specific cache
  def clear_cache(prefix)
    Rails.cache.delete(analytics_cache_key(prefix))
  end

  # Batch cache operations for multiple keys
  def batch_cache_fetch(keys_and_methods)
    results = {}

    keys_and_methods.each do |key, method|
      results[key] = Rails.cache.fetch(
        analytics_cache_key(key),
        expires_in: CACHE_EXPIRY[:medium]
      ) do
        send(method)
      end
    end

    results
  end

  # Conditional caching based on data freshness
  def conditionally_cached(key, options = {})
    cache_key = analytics_cache_key(key)
    expires_in = options[:expires_in] || CACHE_EXPIRY[:medium]
    force_refresh = options[:force_refresh] || false

    if force_refresh
      Rails.cache.delete(cache_key)
    end

    Rails.cache.fetch(cache_key, expires_in: expires_in) do
      yield
    end
  end

  # Fragment caching helper for views
  def analytics_fragment_cache_key(fragment_name)
    [
      "analytics",
      fragment_name,
      current_user.id,
      @start_date,
      @end_date,
      params[:filters]&.to_json
    ].compact.join("-")
  end

  # Check if cache is stale
  def cache_stale?(key, threshold = 5.minutes)
    cache_entry = Rails.cache.read(analytics_cache_key(key))
    return true if cache_entry.nil?

    # Check if the cached data is older than threshold
    cache_metadata = Rails.cache.read("#{analytics_cache_key(key)}_metadata")
    return true if cache_metadata.nil?

    Time.current - cache_metadata[:cached_at] > threshold
  end

  # Warm up cache in background
  def warm_cache_async
    AnalyticsCacheWarmupJob.perform_later(current_user.id, @start_date, @end_date)
  end

  # Preload commonly accessed data
  def preload_analytics_cache
    Rails.cache.fetch_multi(
      analytics_cache_key("overview_metrics"),
      analytics_cache_key("performance_data"),
      analytics_cache_key("conversion_funnel"),
      analytics_cache_key("top_performers")
    ) do |key|
      case key
      when /overview_metrics/
        calculate_overview_metrics
      when /performance_data/
        fetch_performance_data
      when /conversion_funnel/
        calculate_conversion_funnel
      when /top_performers/
        fetch_top_performers
      end
    end
  end
end
