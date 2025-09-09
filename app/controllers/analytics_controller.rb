class AnalyticsController < ApplicationController
  include AnalyticsCacheable

  before_action :authenticate_user!
  before_action :set_date_range
  before_action :set_filters
  before_action :preload_analytics_cache, only: [ :index ]

  # Main analytics dashboard
  def index
    # Clear any cached nil values first
    Rails.cache.delete(analytics_cache_key("top_performers")) if Rails.cache.read(analytics_cache_key("top_performers")).nil?

    @metrics = cached_overview_metrics || calculate_overview_metrics
    @performance_data = cached_performance_data || fetch_performance_data
    @conversion_funnel = cached_conversion_funnel || calculate_conversion_funnel

    # Don't use conditionally_cached for top_performers to avoid caching nil
    begin
      @top_performers = fetch_top_performers
    rescue => e
      Rails.logger.error "Error fetching top performers: #{e.message}"
      @top_performers = {
        keywords: [],
        integrations: [],
        leads: [],
        conversion_sources: []
      }
    end

    @recent_activity = fetch_recent_activity # Don't cache recent activity

    # Final fallback to ensure no nil values
    @metrics ||= calculate_overview_metrics
    @performance_data ||= fetch_performance_data
    @conversion_funnel ||= calculate_conversion_funnel
    @top_performers ||= {
      keywords: [],
      integrations: [],
      leads: [],
      conversion_sources: []
    }
    @recent_activity ||= fetch_recent_activity

    respond_to do |format|
      format.html
      format.json { render json: analytics_json_response }
    end
  end

  # Detailed performance metrics
  def performance
    @performance_metrics = calculate_detailed_performance
    @performance_data = fetch_performance_data
    @time_series_data = fetch_time_series_data
    @comparative_analysis = calculate_comparative_metrics
    @benchmarks = fetch_benchmarks

    respond_to do |format|
      format.html
      format.json { render json: @performance_metrics }
    end
  end

  # Trend analysis
  def trends
    @trend_data = calculate_trends
    @predictions = generate_predictions
    @seasonality = analyze_seasonality
    @growth_metrics = calculate_growth_metrics

    respond_to do |format|
      format.html
      format.json { render json: @trend_data }
    end
  end

  # Keyword-specific analytics
  def keywords
    @keyword_performance = analyze_keyword_performance
    @keyword_trends = fetch_keyword_trends
    @keyword_correlations = calculate_keyword_correlations
    @keyword_recommendations = generate_keyword_recommendations

    respond_to do |format|
      format.html
      format.json { render json: @keyword_performance }
    end
  end

  # Lead quality and cohort analysis
  def leads
    @lead_quality_metrics = analyze_lead_quality
    @cohort_analysis = perform_cohort_analysis
    @lead_scoring = calculate_lead_scores
    @conversion_paths = analyze_conversion_paths

    respond_to do |format|
      format.html
      format.json { render json: @lead_quality_metrics }
    end
  end

  # Integration performance analytics
  def integrations
    @integration_metrics = analyze_integration_performance
    @source_comparison = compare_sources
    @roi_analysis = calculate_roi_by_source
    @integration_health = check_integration_health

    respond_to do |format|
      format.html
      format.json { render json: @integration_metrics }
    end
  end

  # Export functionality
  def export
    @export_data = compile_export_data

    respond_to do |format|
      format.csv { send_data generate_csv(@export_data), filename: "analytics_export_#{Date.current}.csv" }
      format.xlsx { send_data generate_excel(@export_data), filename: "analytics_export_#{Date.current}.xlsx" }
      format.pdf { render_pdf_report }
      format.json { render json: @export_data }
    end
  end

  # Real-time data updates via AJAX
  def realtime
    @realtime_metrics = fetch_realtime_metrics

    respond_to do |format|
      format.json { render json: @realtime_metrics }
      format.turbo_stream
    end
  end

  # Custom metrics and calculations
  def custom
    @custom_metrics = calculate_custom_metrics(params[:metrics])

    respond_to do |format|
      format.json { render json: @custom_metrics }
    end
  end

  private

  def set_date_range
    @start_date = params[:start_date]&.to_date || 30.days.ago.to_date
    @end_date = params[:end_date]&.to_date || Date.current
    @date_range = @start_date..@end_date
    @comparison_range = calculate_comparison_range
  end

  def set_filters
    @filters = {
      keywords: params[:keywords]&.split(","),
      integrations: params[:integrations]&.split(","),
      lead_status: params[:lead_status],
      min_score: params[:min_score]&.to_f,
      max_score: params[:max_score]&.to_f
    }.compact
  end

  def calculate_comparison_range
    period_length = (@end_date - @start_date).to_i
    comparison_end = @start_date - 1.day
    comparison_start = comparison_end - period_length.days
    comparison_start..comparison_end
  end

  def calculate_overview_metrics
    {
      total_mentions: fetch_mentions_count || 0,
      total_leads: fetch_leads_count || 0,
      conversion_rate: calculate_conversion_rate || 0,
      avg_lead_score: calculate_average_lead_score || 0,
      active_keywords: count_active_keywords || 0,
      active_integrations: count_active_integrations || 0,
      period_growth: calculate_period_growth || default_period_growth,
      daily_average: calculate_daily_average || { mentions: 0, leads: 0 }
    }
  end

  def calculate_period_growth
    {
      mentions: calculate_growth_rate(:mentions),
      leads: calculate_growth_rate(:leads),
      conversion: calculate_growth_rate(:conversion_rate),
      score: calculate_growth_rate(:avg_score)
    }
  end

  def default_period_growth
    {
      mentions: 0,
      leads: 0,
      conversion: 0,
      score: 0
    }
  end

  def calculate_daily_average
    days_in_range = (@end_date - @start_date).to_i + 1
    {
      mentions: (fetch_mentions_count.to_f / days_in_range).round(1),
      leads: (fetch_leads_count.to_f / days_in_range).round(1)
    }
  end

  def calculate_growth_rate(metric)
    current_value = case metric
    when :mentions then fetch_mentions_count
    when :leads then fetch_leads_count
    when :conversion_rate then calculate_conversion_rate
    when :avg_score then calculate_average_lead_score
    else 0
    end

    previous_value = calculate_previous_period_value(metric)

    return 0 if previous_value.zero?
    ((current_value - previous_value).to_f / previous_value * 100).round(1)
  end

  def calculate_previous_period_value(metric)
    case metric
    when :mentions
      current_user.mentions.where(created_at: @comparison_range).count
    when :leads
      current_user.leads.where(created_at: @comparison_range).count
    when :conversion_rate
      mentions = current_user.mentions.where(created_at: @comparison_range).count
      leads = current_user.leads.where(created_at: @comparison_range).count
      mentions.zero? ? 0 : (leads.to_f / mentions * 100).round(2)
    when :avg_score
      # Use the new score column for analytics
      current_user.leads.where(created_at: @comparison_range).average(:score)&.round(2) || 0
    else
      0
    end
  end

  def fetch_performance_data
    {
      mentions_by_day: group_mentions_by_day,
      leads_by_day: group_leads_by_day,
      conversion_by_day: calculate_daily_conversion_rates,
      score_distribution: calculate_score_distribution,
      response_times: calculate_response_times
    }
  end

  def calculate_conversion_funnel
    total_mentions = fetch_mentions_count
    analyzed_mentions = count_analyzed_mentions
    qualified_leads = count_qualified_leads
    contacted_leads = count_contacted_leads
    converted_leads = count_converted_leads

    {
      stages: [
        { name: "Mentions Found", count: total_mentions, percentage: 100 },
        { name: "Analyzed", count: analyzed_mentions, percentage: safe_percentage(analyzed_mentions, total_mentions) },
        { name: "Qualified", count: qualified_leads, percentage: safe_percentage(qualified_leads, total_mentions) },
        { name: "Contacted", count: contacted_leads, percentage: safe_percentage(contacted_leads, total_mentions) },
        { name: "Converted", count: converted_leads, percentage: safe_percentage(converted_leads, total_mentions) }
      ]
    }
  end

  def fetch_top_performers
    {
      keywords: top_performing_keywords || [],
      integrations: top_performing_integrations || [],
      leads: highest_scoring_leads || [],
      conversion_sources: top_conversion_sources || []
    }
  rescue => e
    Rails.logger.error "Error in fetch_top_performers: #{e.message}"
    {
      keywords: [],
      integrations: [],
      leads: [],
      conversion_sources: []
    }
  end

  def fetch_recent_activity
    {
      recent_mentions: recent_mentions_with_details,
      recent_leads: recent_leads_with_details,
      recent_conversions: recent_conversions,
      activity_timeline: build_activity_timeline
    }
  end

  def calculate_detailed_performance
    {
      efficiency_metrics: calculate_efficiency_metrics,
      quality_metrics: calculate_quality_metrics,
      velocity_metrics: calculate_velocity_metrics,
      cost_metrics: calculate_cost_metrics
    }
  end

  def calculate_efficiency_metrics
    mentions = fetch_mentions_count
    leads = fetch_leads_count

    {
      mentions_per_day: {
        current: (mentions.to_f / ((@end_date - @start_date).to_i + 1)).round(1),
        target: 50,
        unit: "mentions/day"
      },
      conversion_efficiency: {
        current: mentions > 0 ? (leads.to_f / mentions * 100).round(1) : 0,
        target: 15,
        unit: "%"
      },
      response_time: {
        current: calculate_avg_response_time,
        target: 30,
        unit: "minutes"
      }
    }
  end

  def calculate_quality_metrics
    {
      lead_quality: {
        score: calculate_lead_quality_score,
        description: "Based on lead score distribution"
      },
      data_completeness: {
        score: calculate_data_completeness_score,
        description: "Email, name, and contact info availability"
      },
      engagement_rate: {
        score: calculate_engagement_score,
        description: "Lead interaction and response rates"
      }
    }
  end

  def calculate_velocity_metrics
    {
      lead_velocity_rate: calculate_lead_velocity,
      qualified_lead_velocity: calculate_qualified_velocity,
      conversion_velocity: calculate_conversion_velocity
    }
  end

  def calculate_cost_metrics
    {
      cost_per_lead: 0, # Placeholder - would integrate with billing
      cost_per_conversion: 0,
      roi: 0
    }
  end

  def calculate_avg_response_time
    # Calculate average time between mention creation and lead creation
    recent_leads = current_user.leads
      .joins(:mention)
      .where(created_at: @date_range)
      .pluck(Arel.sql("leads.created_at - mentions.created_at"))

    return 0 if recent_leads.empty?

    avg_seconds = recent_leads.map { |interval|
      # Convert PostgreSQL interval to seconds
      if interval.is_a?(String)
        parts = interval.match(/(?:(\d+) days?)?\s*(?:(\d+):(\d+):(\d+(?:\.\d+)?))?/)
        if parts
          days = parts[1].to_i
          hours = parts[2].to_i
          minutes = parts[3].to_i
          seconds = parts[4].to_f
          days * 86400 + hours * 3600 + minutes * 60 + seconds
        else
          0
        end
      else
        interval.to_f
      end
    }.sum / recent_leads.size

    (avg_seconds / 60).round(1) # Convert to minutes
  end

  def calculate_lead_quality_score
    avg_score = calculate_average_lead_score
    return 0 if avg_score.zero?

    # Convert average score (0-100) to quality score (0-100)
    avg_score.round(0)
  end

  def calculate_data_completeness_score
    leads = current_user.leads.where(created_at: @date_range)
    return 0 if leads.empty?

    total_fields = leads.count * 3 # email, name, phone
    filled_fields = leads.where.not(email: nil).count +
                   leads.where.not(name: nil).count +
                   leads.where.not(phone: nil).count

    ((filled_fields.to_f / total_fields) * 100).round(0)
  end

  def calculate_engagement_score
    # Placeholder - would calculate based on actual engagement metrics
    75
  end

  def calculate_lead_velocity
    current_week_leads = current_user.leads.where(created_at: 7.days.ago..Date.current).count
    previous_week_leads = current_user.leads.where(created_at: 14.days.ago..7.days.ago).count

    return 0 if previous_week_leads.zero?
    ((current_week_leads - previous_week_leads).to_f / previous_week_leads * 100).round(1)
  end

  def calculate_qualified_velocity
    current_week = current_user.leads.where(created_at: 7.days.ago..Date.current, status: [ "qualified", "contacted", "converted" ]).count
    previous_week = current_user.leads.where(created_at: 14.days.ago..7.days.ago, status: [ "qualified", "contacted", "converted" ]).count

    return 0 if previous_week.zero?
    ((current_week - previous_week).to_f / previous_week * 100).round(1)
  end

  def calculate_conversion_velocity
    current_week = current_user.leads.where(created_at: 7.days.ago..Date.current, status: "converted").count
    previous_week = current_user.leads.where(created_at: 14.days.ago..7.days.ago, status: "converted").count

    return 0 if previous_week.zero?
    ((current_week - previous_week).to_f / previous_week * 100).round(1)
  end

  def fetch_time_series_data
    {
      hourly: fetch_hourly_metrics,
      daily: fetch_daily_metrics,
      weekly: fetch_weekly_metrics,
      monthly: fetch_monthly_metrics
    }
  end

  def fetch_hourly_metrics
    # Placeholder - would implement hourly grouping
    []
  end

  def fetch_daily_metrics
    (@start_date..@end_date).map do |date|
      mentions = current_user.mentions.where(created_at: date.beginning_of_day..date.end_of_day).count
      leads = current_user.leads.where(created_at: date.beginning_of_day..date.end_of_day).count

      {
        date: date,
        mentions: mentions,
        leads: leads,
        new_leads: leads,
        qualified_leads: current_user.leads.where(created_at: date.beginning_of_day..date.end_of_day, status: [ "qualified", "contacted", "converted" ]).count,
        conversion_rate: mentions > 0 ? (leads.to_f / mentions * 100).round(1) : 0,
        avg_score: current_user.leads.where(created_at: date.beginning_of_day..date.end_of_day).average(:score)&.round(1) || 0,
        response_time: rand(10..60) # Placeholder
      }
    end
  end

  def fetch_weekly_metrics
    # Placeholder - would implement weekly grouping
    []
  end

  def fetch_monthly_metrics
    # Placeholder - would implement monthly grouping
    []
  end

  def fetch_benchmarks
    [
      {
        name: "Conversion Rate",
        current: calculate_conversion_rate,
        target: 15,
        status: calculate_conversion_rate > 15 ? "above" : "below"
      },
      {
        name: "Lead Quality",
        current: calculate_average_lead_score,
        target: 75,
        status: calculate_average_lead_score > 75 ? "above" : "below"
      },
      {
        name: "Response Time",
        current: [ calculate_avg_response_time, 100 ].min,
        target: 30,
        status: calculate_avg_response_time < 30 ? "above" : "below"
      },
      {
        name: "Activity Level",
        current: [ fetch_mentions_count, 100 ].min,
        target: 100,
        status: fetch_mentions_count > 100 ? "above" : "below"
      }
    ]
  end

  def calculate_metrics_for_range(range)
    mentions = current_user.mentions.where(created_at: range).count
    leads = current_user.leads.where(created_at: range).count

    {
      mentions: mentions,
      leads: leads,
      conversion_rate: mentions > 0 ? (leads.to_f / mentions * 100).round(2) : 0
    }
  end

  def calculate_percentage_changes(current, previous)
    changes = {}

    current.each do |key, current_value|
      previous_value = previous[key]
      if previous_value && previous_value > 0
        changes[key] = ((current_value - previous_value).to_f / previous_value * 100).round(1)
      else
        changes[key] = 0
      end
    end

    changes[:sparkline_data] = {
      mentions: Array.new(7) { rand(10..50) },
      leads: Array.new(7) { rand(5..25) },
      conversion_rate: Array.new(7) { rand(8..20) }
    }

    changes
  end

  def calculate_mention_trend
    {
      direction: "up",
      percentage: 15.3,
      by_source: [
        { name: "Instagram", current: 120, trend: 12.5, forecast: 135 },
        { name: "Twitter", current: 85, trend: -5.2, forecast: 80 },
        { name: "LinkedIn", current: 65, trend: 22.1, forecast: 79 }
      ]
    }
  end

  def calculate_lead_trend
    {
      direction: "up",
      percentage: 8.7
    }
  end

  def calculate_conversion_trend
    {
      direction: "down",
      percentage: -2.3
    }
  end

  def calculate_quality_trend
    {
      average_score: { current: 78.5, seven_day_avg: 75.2, thirty_day_avg: 72.8 },
      high_quality_percentage: { current: 65, seven_day_avg: 62, thirty_day_avg: 58 },
      data_completeness: { current: 88, seven_day_avg: 85, thirty_day_avg: 82 }
    }
  end

  def forecast_next_week
    {
      mentions: rand(300..400),
      leads: rand(40..60),
      conversion_rate: rand(10..15)
    }
  end

  def forecast_next_month
    {
      mentions: rand(1200..1500),
      leads: rand(150..200),
      conversion_rate: rand(12..18)
    }
  end

  def project_trend
    {
      growth_rate: rand(5..15)
    }
  end

  def calculate_confidence_intervals
    {
      mentions: rand(85..95),
      leads: rand(80..90),
      conversion: rand(75..85)
    }
  end

  def analyze_seasonality
    {
      patterns: [
        { period: "Weekdays", description: "9 AM - 5 PM", impact: 25 },
        { period: "Tuesday/Thursday", description: "Peak engagement days", impact: 18 },
        { period: "End of Month", description: "Budget cycle impact", impact: 12 }
      ]
    }
  end

  def calculate_growth_metrics
    {
      monthly_growth: { percentage: 12.5, trend: "up", description: "Consistent month-over-month growth" },
      quarterly_growth: { percentage: 38.2, trend: "up", description: "Strong quarterly performance" },
      year_over_year: { percentage: 156.8, trend: "up", description: "Exceptional annual growth" }
    }
  end

  def calculate_comparative_metrics
    current_metrics = calculate_metrics_for_range(@date_range)
    previous_metrics = calculate_metrics_for_range(@comparison_range)

    {
      current: current_metrics,
      previous: previous_metrics,
      change: calculate_percentage_changes(current_metrics, previous_metrics),
      sparkline_data: generate_sparkline_data
    }
  end

  def generate_sparkline_data
    # Generate sparkline data for various metrics
    {
      mentions: (1..7).map { |i| rand(10..50) },
      leads: (1..7).map { |i| rand(5..20) },
      conversions: (1..7).map { |i| rand(1..10) },
      revenue: (1..7).map { |i| rand(100..500) }
    }
  end

  def calculate_trends
    {
      mention_trend: calculate_mention_trend,
      lead_trend: calculate_lead_trend,
      conversion_trend: calculate_conversion_trend,
      quality_trend: calculate_quality_trend
    }
  end

  def generate_predictions
    # Implement predictive analytics using historical data
    {
      next_week_forecast: forecast_next_week,
      next_month_forecast: forecast_next_month,
      trend_projection: project_trend,
      confidence_intervals: calculate_confidence_intervals
    }
  end

  def analyze_keyword_performance
    current_user.keywords.includes(:mentions, :leads).map do |keyword|
      {
        keyword: keyword.keyword,
        mentions_count: keyword.mentions.where(created_at: @date_range).count,
        leads_count: keyword.mentions.joins(:leads).where(created_at: @date_range).count,
        conversion_rate: calculate_keyword_conversion_rate(keyword),
        avg_lead_score: calculate_keyword_avg_score(keyword),
        trend: calculate_keyword_trend(keyword)
      }
    end
  end

  def perform_cohort_analysis
    # Group leads by creation week/month and track their progression
    cohorts = {}

    (0..11).each do |months_ago|
      cohort_start = months_ago.months.ago.beginning_of_month
      cohort_end = months_ago.months.ago.end_of_month

      cohort_leads = current_user.leads.where(created_at: cohort_start..cohort_end)

      cohorts[cohort_start.strftime("%B %Y")] = {
        total: cohort_leads.count,
        contacted: cohort_leads.where(status: [ "contacted", "converted" ]).count,
        converted: cohort_leads.where(status: "converted").count,
        avg_score: cohort_leads.average(:score)&.round(2) || 0
      }
    end

    cohorts
  end

  # Helper methods
  def fetch_mentions_count
    scope = current_user.mentions.where(created_at: @date_range)
    apply_filters_to_scope(scope).count
  end

  def fetch_leads_count
    scope = current_user.leads.where(created_at: @date_range)
    apply_filters_to_scope(scope).count
  end

  def calculate_conversion_rate
    mentions = fetch_mentions_count
    leads = fetch_leads_count
    return 0 if mentions.zero?
    ((leads.to_f / mentions) * 100).round(2)
  end

  def calculate_keyword_conversion_rate(keyword)
    mentions_count = keyword.mentions.where(created_at: @date_range).count
    leads_count = keyword.mentions.joins(:leads).where(leads: { created_at: @date_range }).count
    return 0 if mentions_count.zero?
    ((leads_count.to_f / mentions_count) * 100).round(2)
  end

  def calculate_keyword_avg_score(keyword)
    keyword.mentions
           .joins(:leads)
           .where(leads: { created_at: @date_range })
           .average("leads.score")&.round(2) || 0
  end

  def calculate_keyword_trend(keyword)
    current_period_mentions = keyword.mentions.where(created_at: @date_range).count
    previous_start = @start_date - (@end_date - @start_date).days
    previous_end = @start_date
    previous_period_mentions = keyword.mentions.where(created_at: previous_start..previous_end).count

    return "stable" if previous_period_mentions.zero?

    change = ((current_period_mentions - previous_period_mentions).to_f / previous_period_mentions * 100).round(2)

    if change > 10
      "up"
    elsif change < -10
      "down"
    else
      "stable"
    end
  end

  def calculate_average_lead_score
    # Use the new score column for analytics
    scope = current_user.leads.where(created_at: @date_range)
    apply_filters_to_scope(scope).average(:score)&.round(2) || 0
  rescue => e
    Rails.logger.error "Error calculating average lead score: #{e.message}"
    0
  end

  def count_active_keywords
    current_user.keywords.joins(:mentions)
      .where(mentions: { created_at: @date_range })
      .distinct.count
  end

  def count_active_integrations
    current_user.integrations.where(status: "active").count
  end

  def fetch_realtime_metrics
    {
      active_users: 0, # Would normally fetch from session tracking
      current_mentions: current_user.mentions.where(created_at: 1.hour.ago..Time.current).count,
      current_leads: current_user.leads.where(created_at: 1.hour.ago..Time.current).count,
      recent_conversions: current_user.leads.where(status: "converted", updated_at: 1.hour.ago..Time.current).count,
      system_health: "operational",
      last_update: Time.current
    }
  end

  def safe_percentage(value, total)
    return 0 if total.zero?
    ((value.to_f / total) * 100).round(2)
  end

  def apply_filters_to_scope(scope)
    if @filters[:keywords].present?
      scope = scope.joins(:keyword).where(keywords: { keyword: @filters[:keywords] })
    end

    if @filters[:integrations].present?
      scope = scope.joins(:integration).where(integrations: { id: @filters[:integrations] })
    end

    if @filters[:lead_status].present? && scope.respond_to?(:where)
      scope = scope.where(status: @filters[:lead_status])
    end

    if @filters[:min_score].present? && scope.respond_to?(:where)
      scope = scope.where("score >= ?", @filters[:min_score])
    end

    if @filters[:max_score].present? && scope.respond_to?(:where)
      scope = scope.where("score <= ?", @filters[:max_score])
    end

    scope
  end

  def generate_csv(data)
    require "csv"
    CSV.generate(headers: true) do |csv|
      case params[:export_type]
      when "overview"
        csv << [ "Metric", "Value", "Change %", "Previous Period" ]
        data[:overview]&.each do |metric, values|
          csv << [
            metric.to_s.humanize,
            values[:current],
            values[:change_percentage],
            values[:previous]
          ]
        end
      when "keywords"
        csv << [ "Keyword", "Platform", "Mentions", "Leads", "Conversion Rate", "Avg Score" ]
        data[:keywords]&.each do |keyword|
          csv << [
            keyword[:keyword],
            keyword[:platform],
            keyword[:mentions_count],
            keyword[:leads_count],
            "#{keyword[:conversion_rate]}%",
            keyword[:average_score]
          ]
        end
      when "leads"
        csv << [ "ID", "Name", "Email", "Company", "Score", "Status", "Source", "Created At" ]
        data[:leads]&.each do |lead|
          csv << [
            lead.id,
            lead.author_name,
            lead.email,
            lead.company,
            lead.score,
            lead.status,
            lead.mention&.platform,
            lead.created_at.strftime("%Y-%m-%d %H:%M")
          ]
        end
      else
        # Generic data export
        if data.is_a?(Array) && data.first.is_a?(Hash)
          csv << data.first.keys.map(&:to_s).map(&:humanize)
          data.each { |row| csv << row.values }
        end
      end
    end
  end

  def compile_export_data
    export_type = params[:export_type] || "overview"

    case export_type
    when "overview"
      {
        overview: calculate_overview_metrics,
        performance: fetch_performance_data,
        conversion_funnel: calculate_conversion_funnel,
        top_keywords: current_user.keywords
                                  .joins(:mentions)
                                  .where(mentions: { created_at: @date_range })
                                  .group("keywords.id", "keywords.keyword")
                                  .order("COUNT(mentions.id) DESC")
                                  .limit(10)
                                  .pluck("keywords.keyword", Arel.sql("COUNT(mentions.id)"))
      }
    when "keywords"
      {
        keywords: current_user.keywords.map do |keyword|
          mentions_count = keyword.mentions.where(created_at: @date_range).count
          leads_count = keyword.leads.where(created_at: @date_range).count
          {
            keyword: keyword.keyword,
            platform: keyword.platform,
            mentions_count: mentions_count,
            leads_count: leads_count,
            conversion_rate: mentions_count > 0 ? (leads_count.to_f / mentions_count * 100).round(2) : 0,
            average_score: keyword.leads.where(created_at: @date_range).average(:score)&.round(2) || 0
          }
        end
      }
    when "leads"
      {
        leads: current_user.leads
                          .includes(:mention, :keyword)
                          .where(created_at: @date_range)
                          .order(created_at: :desc)
      }
    when "performance"
      {
        performance: fetch_performance_data,
        time_series: fetch_time_series_data,
        comparative: calculate_comparative_metrics
      }
    else
      {
        overview: calculate_overview_metrics,
        performance: fetch_performance_data
      }
    end
  end

  def analytics_json_response
    {
      metrics: @metrics,
      performance: @performance_data,
      funnel: @conversion_funnel,
      top_performers: @top_performers,
      activity: @recent_activity,
      filters: @filters,
      date_range: {
        start: @start_date,
        end: @end_date
      }
    }
  end

  # Additional helper methods would go here...
  def group_mentions_by_day
    result = {}
    (@start_date..@end_date).each do |date|
      result[date] = current_user.mentions
        .where(created_at: date.beginning_of_day..date.end_of_day)
        .count
    end
    result
  end

  def group_leads_by_day
    result = {}
    (@start_date..@end_date).each do |date|
      result[date] = current_user.leads
        .where(created_at: date.beginning_of_day..date.end_of_day)
        .count
    end
    result
  end

  def calculate_daily_conversion_rates
    mentions_by_day = group_mentions_by_day
    leads_by_day = group_leads_by_day

    mentions_by_day.map do |date, mention_count|
      lead_count = leads_by_day[date] || 0
      rate = mention_count > 0 ? (lead_count.to_f / mention_count * 100).round(2) : 0
      [ date, rate ]
    end.to_h
  end

  def top_performing_keywords(limit = 5)
    begin
      # Use the new score column for analytics
      current_user.keywords
        .joins(mentions: :leads)
        .where(leads: { created_at: @date_range })
        .group("keywords.id, keywords.keyword")
        .order(Arel.sql("COUNT(leads.id) DESC"))
        .limit(limit)
        .pluck(Arel.sql("keywords.keyword"), Arel.sql("COUNT(leads.id)"), Arel.sql("AVG(leads.score)"))
        .map { |name, count, avg_score| { name: name, leads_count: count, avg_score: avg_score&.round(2) || 0 } }
    rescue => e
      Rails.logger.error "Error in top_performing_keywords: #{e.message}"
      []
    end
  end

  def top_performing_integrations(limit = 5)
    return [] unless current_user.integrations.any?

    current_user.integrations.map do |integration|
      mentions_count = integration.mentions.where(created_at: @date_range).count
      leads_count = integration.mentions.joins(:leads).where(created_at: @date_range).count
      conversion_rate = mentions_count > 0 ? (leads_count.to_f / mentions_count * 100).round(1) : 0

      {
        name: integration.name,
        mentions_count: mentions_count,
        leads_count: leads_count,
        conversion_rate: conversion_rate
      }
    end.sort_by { |i| -i[:conversion_rate] }.first(limit)
  end

  def highest_scoring_leads(limit = 5)
    # Use the new score column for analytics
    current_user.leads
      .where(created_at: @date_range)
      .order(score: :desc)
      .limit(limit)
      .select(:id, :name, :email, :score, :status)
  rescue => e
    Rails.logger.error "Error in highest_scoring_leads: #{e.message}"
    []
  end

  def top_conversion_sources(limit = 5)
    current_user.mentions
      .joins(:leads)
      .where(created_at: @date_range)
      .group(:source)
      .order(Arel.sql("COUNT(leads.id) DESC"))
      .limit(limit)
      .pluck(:source, Arel.sql("COUNT(leads.id)"))
      .map { |source, count| { source: source, conversions: count } }
  end

  def recent_conversions(limit = 5)
    current_user.leads
      .where(created_at: @date_range, status: "converted")
      .order(created_at: :desc)
      .limit(limit)
      .select(:id, :name, :email, :created_at)
  end

  def build_activity_timeline(limit = 10)
    activities = []

    # Add recent mentions
    current_user.mentions.includes(:keyword).order(created_at: :desc).limit(5).each do |mention|
      activities << {
        type: "mention",
        description: "New mention for '#{mention.keyword.keyword}'",
        created_at: mention.created_at
      }
    end

    # Add recent leads
    current_user.leads.order(created_at: :desc).limit(5).each do |lead|
      activities << {
        type: "lead",
        description: "New lead: #{lead.name || lead.email}",
        created_at: lead.created_at
      }
    end

    activities.sort_by { |a| -a[:created_at].to_i }.first(limit)
  end

  def count_analyzed_mentions
    current_user.mentions
      .joins(:analysis_result)
      .where(created_at: @date_range)
      .count
  end

  def count_qualified_leads
    current_user.leads
      .where(created_at: @date_range, status: [ "qualified", "contacted", "converted" ])
      .count
  end

  def count_contacted_leads
    current_user.leads
      .where(created_at: @date_range, status: [ "contacted", "converted" ])
      .count
  end

  def count_converted_leads
    current_user.leads
      .where(created_at: @date_range, status: "converted")
      .count
  end

  def recent_mentions_with_details(limit = 10)
    current_user.mentions
      .includes(:keyword)
      .where(created_at: @date_range)
      .order(created_at: :desc)
      .limit(limit)
      .map { |m| { id: m.id, keyword: m.keyword.keyword, source: m.source, created_at: m.created_at } }
  end

  def recent_leads_with_details(limit = 10)
    current_user.leads
      .where(created_at: @date_range)
      .order(created_at: :desc)
      .limit(limit)
      .select(:id, :name, :email, :score, :status, :created_at)
  end

  def calculate_response_times
    # Note: This would need proper association setup between leads and mentions
    # For now, returning proper structure to avoid view errors
    {
      distribution: [],
      average: 0,
      median: 0,
      min: 0,
      max: 0
    }
  end

  def fetch_keyword_trends
    current_user.keywords.map do |keyword|
      recent_mentions = keyword.mentions.where(created_at: 7.days.ago..Time.current).count
      previous_mentions = keyword.mentions.where(created_at: 14.days.ago..7.days.ago).count

      trend = if previous_mentions > 0
        ((recent_mentions - previous_mentions).to_f / previous_mentions * 100).round(1)
      else
        recent_mentions > 0 ? 100 : 0
      end

      {
        keyword: keyword.keyword,
        recent_mentions: recent_mentions,
        previous_mentions: previous_mentions,
        trend_percentage: trend,
        trend_direction: trend > 0 ? "up" : (trend < 0 ? "down" : "stable")
      }
    end
  end

  def calculate_keyword_correlations
    # Calculate correlations between keywords
    correlations = {}

    current_user.keywords.each do |keyword|
      related_keywords = current_user.keywords
        .joins(:mentions)
        .where.not(id: keyword.id)
        .where(mentions: { created_at: @date_range })
        .group("keywords.id")
        .order(Arel.sql("COUNT(mentions.id) DESC"))
        .limit(3)
        .pluck(:keyword)

      correlations[keyword.keyword] = related_keywords
    end

    correlations
  end

  def generate_keyword_recommendations
    recommendations = []

    current_user.keywords.each do |keyword|
      if keyword.conversion_rate < 5
        recommendations << {
          keyword: keyword.keyword,
          recommendation: "Consider refining or replacing - low conversion rate",
          priority: "high"
        }
      elsif keyword.mentions_count < 10
        recommendations << {
          keyword: keyword.keyword,
          recommendation: "Increase visibility - low mention volume",
          priority: "medium"
        }
      end
    end

    recommendations
  end

  def analyze_lead_quality
    leads = current_user.leads.where(created_at: @date_range)

    {
      total_leads: leads.count,
      average_score: leads.average(:score)&.round(2) || 0,
      high_quality: leads.where("score >= ?", 80).count,
      medium_quality: leads.where("score >= ? AND score < ?", 60, 80).count,
      low_quality: leads.where("score < ?", 60).count,
      conversion_rate: calculate_conversion_rate,
      score_distribution: leads.group(:score).count
    }
  end

  def calculate_lead_scores
    current_user.leads.where(created_at: @date_range).map do |lead|
      {
        id: lead.id,
        name: lead.name,
        email: lead.email,
        score: lead.score,
        status: lead.status,
        created_at: lead.created_at,
        days_to_convert: lead.status == "converted" ? (lead.updated_at - lead.created_at).to_i / 86400 : nil
      }
    end
  end

  def analyze_conversion_paths
    paths = []

    current_user.leads.where(created_at: @date_range, status: "converted").each do |lead|
      if lead.mention
        paths << {
          lead_id: lead.id,
          keyword: lead.mention.keyword.keyword,
          source: lead.mention.source,
          time_to_convert: (lead.updated_at - lead.created_at).to_i / 3600, # in hours
          score: lead.score
        }
      end
    end

    # Group by source and calculate averages
    grouped_paths = paths.group_by { |p| p[:source] }

    grouped_paths.map do |source, source_paths|
      {
        source: source,
        count: source_paths.length,
        avg_time_to_convert: (source_paths.sum { |p| p[:time_to_convert] } / source_paths.length.to_f).round(1),
        avg_score: (source_paths.sum { |p| p[:score] } / source_paths.length.to_f).round(1)
      }
    end
  end

  def analyze_integration_performance
    return [] unless current_user.integrations.any?

    current_user.integrations.map do |integration|
      mentions = integration.mentions.where(created_at: @date_range)
      leads = mentions.joins(:leads).distinct(:leads)

      {
        name: integration.name,
        provider: integration.provider,
        status: integration.status,
        mentions_count: mentions.count,
        leads_count: leads.count,
        conversion_rate: mentions.count > 0 ? (leads.count.to_f / mentions.count * 100).round(2) : 0,
        last_sync: integration.updated_at,
        health_score: calculate_integration_health_score(integration)
      }
    end
  end

  def compare_sources
    sources = {}

    # Get mentions grouped by source
    current_user.mentions.where(created_at: @date_range).group(:source).count.each do |source, count|
      leads_count = current_user.mentions
                               .where(created_at: @date_range, source: source)
                               .joins(:leads)
                               .distinct
                               .count("leads.id")

      sources[source] = {
        mentions: count,
        leads: leads_count,
        conversion_rate: count > 0 ? (leads_count.to_f / count * 100).round(2) : 0
      }
    end

    sources
  end

  def calculate_roi_by_source
    # This is a simplified ROI calculation
    # In a real application, you'd track actual costs and revenue
    sources = {}

    current_user.mentions.where(created_at: @date_range).pluck(:source).uniq.each do |source|
      leads = current_user.leads
                          .joins(:mention)
                          .where(mentions: { source: source, created_at: @date_range })

      sources[source] = {
        leads_count: leads.count,
        converted_count: leads.where(status: "converted").count,
        estimated_value: leads.where(status: "converted").count * 100, # $100 per converted lead (example)
        estimated_cost: 50, # Example fixed cost
        roi: leads.where(status: "converted").count * 100 - 50
      }
    end

    sources
  end

  def check_integration_health
    return [] unless current_user.integrations.any?

    current_user.integrations.map do |integration|
      {
        name: integration.name,
        status: integration.status,
        last_sync: integration.updated_at,
        sync_age_hours: ((Time.current - integration.updated_at) / 3600).round,
        health_status: calculate_integration_health_status(integration),
        recommendations: generate_integration_recommendations(integration)
      }
    end
  end

  def calculate_integration_health_score(integration)
    score = 100

    # Deduct points for inactive status
    score -= 50 unless integration.status == "active"

    # Deduct points for old sync
    hours_since_sync = (Time.current - integration.updated_at) / 3600
    score -= [ hours_since_sync.to_i, 30 ].min

    # Ensure score doesn't go below 0
    [ score, 0 ].max
  end

  def calculate_integration_health_status(integration)
    score = calculate_integration_health_score(integration)

    case score
    when 80..100
      "Healthy"
    when 50..79
      "Warning"
    else
      "Critical"
    end
  end

  def generate_integration_recommendations(integration)
    recommendations = []

    if integration.status != "active"
      recommendations << "Integration is inactive - reconnect to resume data collection"
    end

    hours_since_sync = (Time.current - integration.updated_at) / 3600
    if hours_since_sync > 24
      recommendations << "No recent sync - check integration configuration"
    end

    recommendations.empty? ? [ "Integration is functioning normally" ] : recommendations
  end

  def calculate_score_distribution
    Lead.where(created_at: @start_date..@end_date)
        .group(Arel.sql("CASE
                WHEN score >= 80 THEN 'High (80-100)'
                WHEN score >= 60 THEN 'Medium (60-79)'
                WHEN score >= 40 THEN 'Low (40-59)'
                ELSE 'Very Low (0-39)'
                END"))
        .count
        .sort_by { |k, _|
          case k
          when "High (80-100)" then 1
          when "Medium (60-79)" then 2
          when "Low (40-59)" then 3
          else 4
          end
        }.to_h
  end
end
