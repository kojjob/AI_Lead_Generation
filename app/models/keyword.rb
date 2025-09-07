class Keyword < ApplicationRecord
  self.inheritance_column = nil # Disable single-table inheritance

  belongs_to :user, counter_cache: true
  has_many :mentions, dependent: :destroy
  has_many :leads, through: :mentions

  # Handle platforms as comma-separated string
  def platforms_array
    platforms.to_s.split(",").map(&:strip)
  end

  def platforms_array=(values)
    self.platforms = values.reject(&:blank?).join(",")
  end

  # Validations
  validates :keyword, presence: true, uniqueness: { scope: :user_id }
  validates :user, presence: true
  validates :priority, inclusion: { in: %w[low medium high], message: "must be low, medium, or high" }
  validates :notification_frequency, inclusion: { in: %w[instant daily weekly none], message: "must be instant, daily, weekly, or none" }

  # Scopes
  scope :active, -> { where(status: "active") }
  scope :by_performance, -> { joins(:leads).group("keywords.id").order("COUNT(leads.id) DESC") }

  # Instance methods
  def conversion_rate
    return 0 if mentions_count.zero?
    (leads_count.to_f / mentions_count * 100).round(2)
  end

  def performance_score
    # Simple scoring based on conversion rate and volume
    base_score = conversion_rate
    volume_bonus = [ mentions_count / 10.0, 20 ].min # Max 20 points for volume
    [ base_score + volume_bonus, 100 ].min
  end

  def last_mention_at
    mentions.maximum(:created_at)
  end

  # AI-Powered Features
  def analyze_potential
    KeywordRecommendationService.new(user).analyze_keyword_potential(keyword)
  end

  def sentiment_distribution
    mentions.joins(:analysis_result)
            .group('CASE
                     WHEN analysis_results.sentiment_score > 0.1 THEN \'positive\'
                     WHEN analysis_results.sentiment_score < -0.1 THEN \'negative\'
                     ELSE \'neutral\'
                   END')
            .count
  end

  def average_sentiment
    mentions.joins(:analysis_result)
            .average("analysis_results.sentiment_score") || 0.0
  end

  def quality_leads_count
    leads.where(quality_tier: "high").count
  end

  def quality_leads_percentage
    return 0 if leads_count.zero?
    (quality_leads_count.to_f / leads_count * 100).round(1)
  end

  def trending_score
    # Calculate trending based on recent mention volume
    recent_mentions = mentions.where(created_at: 7.days.ago..Time.current).count
    older_mentions = mentions.where(created_at: 14.days.ago..7.days.ago).count

    return 0 if older_mentions.zero?

    growth_rate = (recent_mentions - older_mentions).to_f / older_mentions
    [ growth_rate * 100, 100 ].min
  end

  def engagement_score
    # Calculate engagement based on mention characteristics
    total_mentions = mentions.count
    return 0 if total_mentions.zero?

    # Count mentions with high engagement indicators
    engaged_mentions = mentions.joins(:analysis_result)
                              .where("analysis_results.sentiment_score > 0.3")
                              .count

    (engaged_mentions.to_f / total_mentions * 100).round(1)
  end

  def performance_insights
    {
      conversion_rate: conversion_rate,
      quality_leads_percentage: quality_leads_percentage,
      average_sentiment: average_sentiment.round(3),
      trending_score: trending_score.round(1),
      engagement_score: engagement_score,
      total_mentions: mentions_count,
      total_leads: leads_count,
      last_activity: last_mention_at
    }
  end

  def optimization_suggestions
    suggestions = []
    insights = performance_insights

    if insights[:conversion_rate] < 5
      suggestions << "Low conversion rate - consider refining keyword targeting"
    end

    if insights[:average_sentiment] < 0
      suggestions << "Negative sentiment detected - monitor brand mentions closely"
    end

    if insights[:trending_score] < -20
      suggestions << "Declining mention volume - keyword may be losing relevance"
    end

    if insights[:engagement_score] < 30
      suggestions << "Low engagement - consider more specific long-tail variations"
    end

    if mentions_count < 10
      suggestions << "Low mention volume - consider broader keyword variations"
    end

    suggestions.presence || [ "Keyword performing well - continue monitoring" ]
  end

  def related_keyword_suggestions
    KeywordRecommendationService.new(user).generate_recommendations(limit: 5)[:recommendations]
                                 .select { |rec| rec[:keyword].include?(keyword.split.first) }
                                 .first(3)
  end

  # Class methods for AI features
  def self.generate_recommendations_for_user(user, limit: 10)
    KeywordRecommendationService.generate_for_user(user, limit: limit)
  end

  def self.performance_leaderboard(limit: 10)
    joins(:mentions, :leads)
      .group("keywords.id")
      .select('keywords.*,
               COUNT(DISTINCT mentions.id) as mention_count,
               COUNT(DISTINCT leads.id) as lead_count,
               CASE
                 WHEN COUNT(DISTINCT mentions.id) > 0
                 THEN (COUNT(DISTINCT leads.id)::float / COUNT(DISTINCT mentions.id) * 100)
                 ELSE 0
               END as conversion_rate')
      .order("conversion_rate DESC, mention_count DESC")
      .limit(limit)
  end

  def self.trending_keywords(days: 7)
    recent_period = days.days.ago..Time.current
    previous_period = (days * 2).days.ago..days.days.ago

    joins(:mentions)
      .group("keywords.id")
      .select('keywords.*,
               COUNT(CASE WHEN mentions.created_at BETWEEN ? AND ? THEN 1 END) as recent_count,
               COUNT(CASE WHEN mentions.created_at BETWEEN ? AND ? THEN 1 END) as previous_count',
               recent_period.begin, recent_period.end,
               previous_period.begin, previous_period.end)
      .having('COUNT(CASE WHEN mentions.created_at BETWEEN ? AND ? THEN 1 END) >
               COUNT(CASE WHEN mentions.created_at BETWEEN ? AND ? THEN 1 END)',
               recent_period.begin, recent_period.end,
               previous_period.begin, previous_period.end)
      .order("recent_count DESC")
  end

  def self.sentiment_leaders
    joins(mentions: :analysis_result)
      .group("keywords.id")
      .select("keywords.*, AVG(analysis_results.sentiment_score) as avg_sentiment")
      .having("COUNT(analysis_results.id) >= 5") # Minimum 5 analyzed mentions
      .order("avg_sentiment DESC")
  end

  def self.needs_optimization
    where("mentions_count > 10 AND leads_count < mentions_count * 0.05") # Less than 5% conversion
  end
end
