class DashboardService
  def initialize(user)
    @user = user
  end

  def analytics_data
    Rails.cache.fetch(["dashboard", "analytics", @user.id], expires_in: 5.minutes) do
      {
        stats: fetch_stats,
        leads_chart_data: fetch_leads_chart_data,
        conversion_chart_data: fetch_conversion_chart_data,
        platform_breakdown: fetch_platform_breakdown,
        top_keywords: fetch_top_keywords,
        recent_activity: fetch_recent_activity
      }
    end
  end

  def dashboard_data
    Rails.cache.fetch(["dashboard", "main", @user.id], expires_in: 5.minutes) do
      {
        stats: fetch_basic_stats,
        recent_leads: fetch_recent_leads,
        recent_mentions: fetch_recent_mentions,
        keyword_performance: fetch_keyword_performance
      }
    end
  end

  private

  def fetch_stats
    {
      total_keywords: @user.keywords_count,
      active_keywords: @user.keywords.active.count,
      total_mentions: @user.keywords.joins(:mentions).count,
      total_leads: @user.leads_count,
      qualified_leads: @user.leads.qualified.count,
      conversion_rate: calculate_conversion_rate
    }
  end

  def fetch_basic_stats
    {
      total_keywords: @user.keywords_count,
      total_leads: @user.leads_count,
      new_leads_today: @user.leads.where(created_at: Time.current.beginning_of_day..).count,
      active_integrations: @user.integrations_count
    }
  end

  def fetch_recent_leads
    @user.leads
         .includes(:mention, :keyword)
         .recent
         .limit(5)
         .select(:id, :name, :email, :status, :qualification_score, :created_at)
  end

  def fetch_recent_mentions
    Mention.joins(:keyword)
           .where(keywords: { user_id: @user.id })
           .includes(:keyword)
           .recent
           .limit(10)
           .select(:id, :content, :posted_at, :url, :keyword_id)
  end

  def fetch_keyword_performance
    @user.keywords
         .active
         .includes(:mentions, :leads)
         .limit(5)
         .map do |keyword|
           {
             id: keyword.id,
             keyword: keyword.keyword,
             mentions_count: keyword.mentions_count,
             leads_count: keyword.leads_count,
             conversion_rate: keyword.conversion_rate
           }
         end
  end

  def fetch_leads_chart_data
    end_date = Date.current
    start_date = end_date - 30.days
    
    leads_by_day = @user.leads
                        .where(created_at: start_date..end_date)
                        .group_by_day(:created_at)
                        .count
    
    (start_date..end_date).map do |date|
      {
        date: date.strftime('%Y-%m-%d'),
        count: leads_by_day[date] || 0
      }
    end
  end

  def fetch_conversion_chart_data
    @user.keywords
         .active
         .joins(:mentions, :leads)
         .group('keywords.keyword')
         .pluck(
           'keywords.keyword',
           'COUNT(DISTINCT mentions.id)',
           'COUNT(DISTINCT leads.id)'
         )
         .map do |keyword, mentions, leads|
           {
             keyword: keyword,
             mentions: mentions,
             leads: leads,
             rate: mentions > 0 ? (leads.to_f / mentions * 100).round(2) : 0
           }
         end
  end

  def fetch_platform_breakdown
    Mention.joins(:keyword)
           .where(keywords: { user_id: @user.id })
           .group(:platform)
           .count
           .map { |platform, count| { platform: platform || 'Unknown', count: count } }
  end

  def fetch_top_keywords
    @user.keywords
         .active
         .left_joins(:leads)
         .group('keywords.id')
         .order('COUNT(leads.id) DESC')
         .limit(5)
         .pluck('keywords.keyword', 'keywords.mentions_count', 'COUNT(leads.id)')
         .map do |keyword, mentions, leads|
           {
             keyword: keyword,
             mentions: mentions,
             leads: leads,
             conversion_rate: mentions > 0 ? (leads.to_f / mentions * 100).round(2) : 0
           }
         end
  end

  def fetch_recent_activity
    activities = []
    
    # Recent leads
    recent_leads = @user.leads
                       .recent
                       .limit(5)
                       .select(:id, :name, :created_at)
    
    recent_leads.each do |lead|
      activities << {
        type: 'lead',
        description: "New lead: #{lead.name || 'Unknown'}",
        time: lead.created_at
      }
    end
    
    # Recent mentions
    recent_mentions = Mention.joins(:keyword)
                            .where(keywords: { user_id: @user.id })
                            .recent
                            .limit(5)
                            .select(:id, :posted_at)
                            .includes(:keyword)
    
    recent_mentions.each do |mention|
      activities << {
        type: 'mention',
        description: "New mention for #{mention.keyword.keyword}",
        time: mention.posted_at || mention.created_at
      }
    end
    
    activities.sort_by { |a| a[:time] }.reverse.first(10)
  end

  def calculate_conversion_rate
    total_mentions = @user.keywords.joins(:mentions).count
    return 0 if total_mentions.zero?
    
    (@user.leads_count.to_f / total_mentions * 100).round(2)
  end
end