class DashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :set_dashboard_data

  def index
    # Main dashboard view with all widgets and analytics
  end

  def analytics
    # Detailed analytics view
    render json: {
      leads: @analytics_data[:leads],
      conversions: @analytics_data[:conversions],
      keywords: @analytics_data[:keywords],
      integrations: @analytics_data[:integrations]
    }
  end

  def widgets
    # Return widget data for AJAX updates
    render json: {
      recent_leads: @recent_leads,
      keyword_performance: @keyword_performance,
      integration_status: @integration_status,
      conversion_metrics: @conversion_metrics
    }
  end

  private

  def set_dashboard_data
    @user = current_user

    # Use simple queries to avoid complex joins
    @user_keywords = current_user.keywords
    @user_integrations = current_user.integrations

    # Get data through simpler approach to avoid ambiguous column errors
    keyword_ids = @user_keywords.pluck(:id)
    mention_ids = keyword_ids.any? ? Mention.where(keyword_id: keyword_ids).pluck(:id) : []

    # Recent leads data
    @recent_leads = mention_ids.any? ? Lead.where(mention_id: mention_ids).includes(:mention).order(created_at: :desc).limit(10) : []

    # Keyword performance data
    @keyword_performance = @user_keywords.limit(5)

    # Integration status
    @integration_status = @user_integrations

    # Analytics data for charts
    @analytics_data = {
      leads: leads_analytics,
      conversions: conversion_analytics,
      keywords: keyword_analytics,
      integrations: integration_analytics
    }

    # Conversion metrics
    @conversion_metrics = calculate_conversion_metrics

    # Notification data (placeholder for now)
    @notifications = []
  end

  def leads_analytics
    # Get leads through mentions to avoid complex joins
    keyword_ids = @user_keywords.pluck(:id)
    mention_ids = keyword_ids.any? ? Mention.where(keyword_id: keyword_ids).pluck(:id) : []

    if mention_ids.any?
      # Last 30 days of lead data
      leads_by_day = Lead.where(mention_id: mention_ids)
                         .where(created_at: 30.days.ago..Time.current)
                         .group("DATE(created_at)")
                         .count

      # Convert to a more readable format
      formatted_leads_by_day = {}
      (30.days.ago.to_date..Date.current).each do |date|
        formatted_leads_by_day[date] = leads_by_day[date.to_s] || 0
      end

      total_leads = Lead.where(mention_id: mention_ids).count
      this_month = Lead.where(mention_id: mention_ids).where(created_at: 1.month.ago..Time.current).count
      last_month = Lead.where(mention_id: mention_ids).where(created_at: 2.months.ago..1.month.ago).count
    else
      formatted_leads_by_day = {}
      (30.days.ago.to_date..Date.current).each do |date|
        formatted_leads_by_day[date] = 0
      end
      total_leads = 0
      this_month = 0
      last_month = 0
    end

    {
      daily_leads: formatted_leads_by_day,
      total_leads: total_leads,
      this_month: this_month,
      last_month: last_month
    }
  end

  def conversion_analytics
    # Get data through simpler queries
    keyword_ids = @user_keywords.pluck(:id)
    mention_ids = keyword_ids.any? ? Mention.where(keyword_id: keyword_ids).pluck(:id) : []

    if mention_ids.any?
      total_mentions = Mention.where(keyword_id: keyword_ids).count
      qualified_leads = Lead.where(mention_id: mention_ids).count
      contacted_leads = Lead.where(mention_id: mention_ids).where.not(last_contacted_at: nil).count
      converted_leads = Lead.where(mention_id: mention_ids).where(status: 'converted').count
    else
      total_mentions = 0
      qualified_leads = 0
      contacted_leads = 0
      converted_leads = 0
    end

    {
      mentions: total_mentions,
      qualified: qualified_leads,
      contacted: contacted_leads,
      converted: converted_leads,
      conversion_rate: total_mentions > 0 ? (converted_leads.to_f / total_mentions * 100).round(2) : 0
    }
  end

  def keyword_analytics
    # Keyword performance over time
    keyword_data = @user_keywords.map do |keyword|
      mentions_count = Mention.where(keyword_id: keyword.id).count
      leads_count = Lead.joins(:mention).where(mentions: { keyword_id: keyword.id }).count

      {
        name: keyword.keyword || 'Unknown', # Use 'keyword' column from schema
        mentions: mentions_count,
        leads: leads_count,
        conversion_rate: mentions_count > 0 ? (leads_count.to_f / mentions_count * 100).round(2) : 0
      }
    end

    keyword_data.sort_by { |k| k[:conversion_rate] }.reverse
  end

  def integration_analytics
    # Integration performance data
    @user_integrations.map do |integration|
      # For now, just return basic integration data since mentions don't have platform column
      keyword_ids = @user_keywords.pluck(:id)
      mentions_count = keyword_ids.any? ? Mention.where(keyword_id: keyword_ids).count : 0

      {
        platform: integration.provider || 'Unknown', # Use 'provider' column from schema
        status: integration.status == 'active' ? 'active' : 'inactive',
        mentions_count: mentions_count,
        last_sync: integration.last_searched_at, # Use available column
        health_score: calculate_integration_health(integration)
      }
    end
  end

  def calculate_conversion_metrics
    keyword_ids = @user_keywords.pluck(:id)
    mention_ids = keyword_ids.any? ? Mention.where(keyword_id: keyword_ids).pluck(:id) : []
    leads = mention_ids.any? ? Lead.where(mention_id: mention_ids) : Lead.none

    {
      total_leads: leads.count,
      new_leads_today: leads.where(created_at: Date.current.beginning_of_day..Date.current.end_of_day).count,
      conversion_rate: calculate_overall_conversion_rate,
      avg_response_time: calculate_avg_response_time(leads),
      top_performing_keyword: find_top_performing_keyword
    }
  end

  def calculate_overall_conversion_rate
    total_mentions = current_user.mentions.count
    converted_leads = current_user.leads.where(status: 'converted').count
    
    return 0 if total_mentions.zero?
    (converted_leads.to_f / total_mentions * 100).round(2)
  end

  def calculate_avg_response_time(leads)
    contacted_leads = leads.where.not(last_contacted_at: nil)
    return 0 if contacted_leads.empty?

    total_time = contacted_leads.sum do |lead|
      (lead.last_contacted_at - lead.created_at) / 1.hour
    end

    (total_time / contacted_leads.count).round(2)
  end

  def find_top_performing_keyword
    return nil if @user_keywords.empty?

    # Find keyword with most leads
    keyword_performance = @user_keywords.map do |keyword|
      leads_count = Lead.joins(:mention).where(mentions: { keyword_id: keyword.id }).count
      { keyword: keyword, leads_count: leads_count }
    end

    top_keyword = keyword_performance.max_by { |kp| kp[:leads_count] }
    top_keyword&.dig(:keyword)&.keyword
  end

  def calculate_integration_health(integration)
    # Simple health score based on recent activity and sync status
    score = 100

    # Deduct points for old last sync
    if integration.last_searched_at
      days_since_sync = (Time.current - integration.last_searched_at) / 1.day
      score -= [days_since_sync * 5, 50].min
    else
      score -= 50
    end

    # Deduct points if inactive
    score -= 30 unless integration.status == 'active'

    [score, 0].max.round
  end
end
