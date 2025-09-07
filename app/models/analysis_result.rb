class AnalysisResult < ApplicationRecord
  self.inheritance_column = nil # Disable single-table inheritance

  belongs_to :mention

  # Validations
  validates :mention, presence: true
  validates :sentiment_score, numericality: { in: -1.0..1.0 }, allow_nil: true

  # Scopes
  scope :positive, -> { where('sentiment_score > 0.1') }
  scope :negative, -> { where('sentiment_score < -0.1') }
  scope :neutral, -> { where('sentiment_score BETWEEN -0.1 AND 0.1') }
  scope :high_confidence, -> { where('confidence > 0.7') }

  # Callbacks
  after_create :trigger_lead_quality_update
  after_update :trigger_lead_quality_update, if: :saved_change_to_sentiment_score?

  # Instance methods
  def sentiment_label
    return 'unknown' if sentiment_score.nil?

    case sentiment_score
    when 0.1..1.0
      'positive'
    when -1.0..-0.1
      'negative'
    else
      'neutral'
    end
  end

  def sentiment_emoji
    SentimentAnalysisService.sentiment_emoji(sentiment_label)
  end

  def sentiment_color
    SentimentAnalysisService.sentiment_color(sentiment_label)
  end

  def confidence_level
    return 'unknown' if confidence.nil?

    case confidence
    when 0.8..1.0
      'high'
    when 0.6..0.8
      'medium'
    when 0.4..0.6
      'low'
    else
      'very_low'
    end
  end

  def analyze_sentiment!
    return unless mention&.content.present?

    result = SentimentAnalysisService.analyze(mention.content)

    update!(
      sentiment_score: result[:score],
      confidence: result[:confidence],
      analysis_provider: result[:provider],
      analysis_details: result[:details]
    )

    result
  rescue StandardError => e
    Rails.logger.error "Failed to analyze sentiment for mention #{mention.id}: #{e.message}"
    nil
  end

  def extract_entities
    return [] unless mention&.content.present?

    # Simple entity extraction - in production, use NLP libraries
    content = mention.content
    entities = []

    # Extract mentions (@username)
    mentions = content.scan(/@(\w+)/).flatten
    entities.concat(mentions.map { |m| { type: 'mention', value: m } })

    # Extract hashtags (#hashtag)
    hashtags = content.scan(/#(\w+)/).flatten
    entities.concat(hashtags.map { |h| { type: 'hashtag', value: h } })

    # Extract URLs
    urls = content.scan(/https?:\/\/[^\s]+/).flatten
    entities.concat(urls.map { |u| { type: 'url', value: u } })

    # Update entities field
    update!(entities: entities) if entities.any?

    entities
  end

  def classify_content
    return unless mention&.content.present?

    content = mention.content.downcase
    classifications = []

    # Intent classification
    if content.match?(/\b(buy|purchase|price|cost)\b/)
      classifications << 'buying_intent'
    elsif content.match?(/\b(compare|vs|versus|alternative)\b/)
      classifications << 'comparison_request'
    elsif content.match?(/\b(problem|issue|help|solution)\b/)
      classifications << 'support_request'
    elsif content.match?(/\b(how|what|when|where|why)\b/)
      classifications << 'information_seeking'
    end

    # Topic classification
    if content.match?(/\b(software|app|tool|platform)\b/)
      classifications << 'software_related'
    elsif content.match?(/\b(service|consulting|support)\b/)
      classifications << 'service_related'
    end

    update!(classification: classifications.join(',')) if classifications.any?
    classifications
  end

  # Class methods
  def self.analyze_batch(mentions)
    mentions.each do |mention|
      analysis_result = mention.analysis_result || mention.build_analysis_result
      analysis_result.analyze_sentiment!
      analysis_result.extract_entities
      analysis_result.classify_content
    end
  end

  def self.sentiment_distribution
    {
      positive: positive.count,
      negative: negative.count,
      neutral: neutral.count,
      total: count
    }
  end

  def self.average_sentiment
    where.not(sentiment_score: nil).average(:sentiment_score) || 0.0
  end

  private

  def trigger_lead_quality_update
    return unless mention&.lead

    # Update lead quality score when sentiment analysis changes
    LeadQualityUpdateJob.perform_later(mention.lead) if Rails.env.production?
  end
end
