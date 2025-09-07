class Lead < ApplicationRecord
  self.inheritance_column = nil # Disable single-table inheritance

  # Associations
  belongs_to :user, counter_cache: true
  belongs_to :mention, optional: true
  has_one :keyword, through: :mention
  has_many :ml_scores, as: :scoreable, dependent: :destroy

  # Validations
  validates :user, presence: true
  validates :status, inclusion: { in: %w[new contacted qualified converted rejected archived] }
  validates :priority, inclusion: { in: %w[low medium high urgent] }
  validates :lead_stage, inclusion: { in: %w[prospect qualified opportunity proposal negotiation closed] }
  validates :temperature, inclusion: { in: %w[cold warm hot] }
  validates :qualification_score, numericality: { in: 0..100 }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :conversion_value, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true

  # Callbacks
  before_save :update_interaction_tracking
  before_save :calculate_qualification_score
  after_update :track_status_changes
  after_create :create_notification

  # Scopes
  scope :new_leads, -> { where(leads: { status: "new" }) }
  scope :contacted, -> { where(leads: { status: "contacted" }) }
  scope :qualified, -> { where(leads: { status: "qualified" }) }
  scope :converted, -> { where(leads: { status: "converted" }) }
  scope :rejected, -> { where(leads: { status: "rejected" }) }
  scope :archived, -> { where(leads: { status: "archived" }) }
  scope :recent, -> { order("leads.created_at DESC") }
  scope :by_priority, -> { order(Arel.sql("CASE leads.priority WHEN 'urgent' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 WHEN 'low' THEN 4 END")) }
  scope :high_value, -> { where("leads.qualification_score >= ?", 70) }
  scope :needs_follow_up, -> { where("leads.next_follow_up <= ? AND leads.status NOT IN (?)", Time.current, %w[converted rejected archived]) }
  scope :hot_leads, -> { where(leads: { temperature: "hot" }) }
  scope :warm_leads, -> { where(leads: { temperature: "warm" }) }
  scope :cold_leads, -> { where(leads: { temperature: "cold" }) }
  scope :by_stage, ->(stage) { where(leads: { lead_stage: stage }) }
  scope :by_platform, ->(platform) { where(leads: { source_platform: platform }) }
  scope :assigned_to, ->(user) { where(leads: { assigned_to: user }) }
  scope :unassigned, -> { where(leads: { assigned_to: [ nil, "" ] }) }

  # Search scope
  scope :search, ->(query) {
    return all if query.blank?

    where(
      "leads.name ILIKE ? OR leads.email ILIKE ? OR leads.company ILIKE ? OR leads.position ILIKE ? OR leads.notes ILIKE ?",
      "%#{query}%", "%#{query}%", "%#{query}%", "%#{query}%", "%#{query}%"
    )
  }

  # Instance methods
  def contacted?
    last_contacted_at.present?
  end

  def converted?
    status == "converted"
  end

  def qualified?
    status == "qualified" || qualification_score >= 50
  end

  def hot?
    temperature == "hot" || qualification_score >= 80
  end

  def needs_follow_up?
    next_follow_up.present? && next_follow_up <= Time.current && !%w[converted rejected archived].include?(status)
  end

  def overdue_follow_up?
    next_follow_up.present? && next_follow_up < Time.current && !%w[converted rejected archived].include?(status)
  end

  def response_time_hours
    return nil unless last_contacted_at && created_at
    ((last_contacted_at - created_at) / 1.hour).round(2)
  end

  def days_since_created
    ((Time.current - created_at) / 1.day).round
  end

  def days_since_last_contact
    return nil unless last_contacted_at
    ((Time.current - last_contacted_at) / 1.day).round
  end

  def full_name_or_email
    name.present? ? name : email.presence || "Unknown Lead"
  end

  def display_company
    company.present? ? company : "Unknown Company"
  end

  def contact_info
    info = []
    info << email if email.present?
    info << phone if phone.present?
    info.join(" • ")
  end

  def priority_color
    case priority
    when "urgent" then "red"
    when "high" then "orange"
    when "medium" then "yellow"
    when "low" then "gray"
    else "gray"
    end
  end

  def status_color
    case status
    when "new" then "blue"
    when "contacted" then "yellow"
    when "qualified" then "purple"
    when "converted" then "green"
    when "rejected" then "red"
    when "archived" then "gray"
    else "gray"
    end
  end

  def temperature_color
    case temperature
    when "hot" then "red"
    when "warm" then "orange"
    when "cold" then "blue"
    else "gray"
    end
  end

  def stage_progress_percentage
    stages = %w[prospect qualified opportunity proposal negotiation closed]
    current_index = stages.index(lead_stage) || 0
    ((current_index + 1).to_f / stages.length * 100).round
  end

  # AI-Powered Features
  def predict_quality
    @quality_prediction ||= LeadQualityPredictionService.new(self).predict_quality
  end

  def update_quality_prediction!
    prediction = predict_quality

    update!(
      quality_score: prediction[:quality_score],
      conversion_probability: prediction[:conversion_probability],
      quality_tier: prediction[:quality_tier]
    )

    prediction
  end

  def generate_response_suggestions(count: 3)
    return [] unless mention&.content.present?

    user_context = {
      company: user.company || "our company",
      name: user.first_name || "there"
    }

    ResponseSuggestionService.generate_for_mention(mention, user_context, count: count)
  end

  def analyze_sentiment
    return unless mention&.content.present?

    analysis_result = mention.analysis_result || mention.build_analysis_result
    analysis_result.analyze_sentiment!
  end

  def quality_tier_color
    case quality_tier
    when 'high'
      'green'
    when 'medium'
      'yellow'
    when 'low'
      'orange'
    when 'very_low'
      'red'
    else
      'gray'
    end
  end

  def quality_tier_badge
    case quality_tier
    when 'high'
      '🔥'
    when 'medium'
      '⭐'
    when 'low'
      '📊'
    when 'very_low'
      '❄️'
    else
      '❓'
    end
  end

  def conversion_probability_percentage
    return 0 unless conversion_probability
    (conversion_probability * 100).round(1)
  end

  def ai_recommendations
    prediction = predict_quality
    prediction[:recommendations] || []
  end

  def suggested_next_action
    prediction = predict_quality

    case prediction[:quality_tier]
    when 'high'
      'Contact immediately - high conversion potential'
    when 'medium'
      'Follow up within 24 hours'
    when 'low'
      'Add to nurturing campaign'
    else
      'Monitor for additional engagement'
    end
  end

  def sentiment_analysis
    mention&.analysis_result
  end

  def sentiment_score
    sentiment_analysis&.sentiment_score || 0.0
  end

  def sentiment_label
    sentiment_analysis&.sentiment_label || 'unknown'
  end

  def sentiment_emoji
    sentiment_analysis&.sentiment_emoji || '❓'
  end

  # Class methods for AI features
  def self.update_quality_scores_batch(leads)
    LeadQualityPredictionService.update_lead_scores(leads)
  end

  def self.analyze_sentiments_batch(leads)
    mentions = leads.includes(:mention).map(&:mention).compact
    AnalysisResult.analyze_batch(mentions)
  end

  def self.quality_distribution
    {
      high: where(quality_tier: 'high').count,
      medium: where(quality_tier: 'medium').count,
      low: where(quality_tier: 'low').count,
      very_low: where(quality_tier: 'very_low').count,
      unknown: where(quality_tier: [nil, '']).count
    }
  end

  def self.average_quality_score
    where.not(quality_score: nil).average(:quality_score) || 0.0
  end

  def self.average_conversion_probability
    where.not(conversion_probability: nil).average(:conversion_probability) || 0.0
  end

  def self.high_quality_leads
    where(quality_tier: 'high')
  end

  def self.needs_ai_analysis
    joins(:mention)
      .left_joins(mention: :analysis_result)
      .where(analysis_results: { id: nil })
      .or(where(quality_score: nil))
  end

  private

  def update_interaction_tracking
    if status_changed? && status_was != "new"
      self.interaction_count += 1
      self.last_interaction_at = Time.current
    end

    if last_contacted_at_changed? && last_contacted_at.present?
      self.interaction_count += 1
      self.last_interaction_at = last_contacted_at
    end
  end

  def calculate_qualification_score
    return if qualification_score_changed? && qualification_score.present?

    score = 0

    # Base score from mention engagement
    if mention&.engagement_score.present?
      score += [ mention.engagement_score * 20, 30 ].min
    end

    # Contact information completeness
    score += 10 if email.present?
    score += 5 if phone.present?
    score += 10 if name.present?
    score += 10 if company.present?
    score += 5 if position.present?

    # Interaction quality
    score += 15 if contacted?
    score += 10 if interaction_count > 1

    # Platform quality
    case source_platform
    when "linkedin" then score += 15
    when "twitter" then score += 10
    when "reddit" then score += 5
    end

    # Recency bonus
    if created_at.present?
      days_old = ((Time.current - created_at) / 1.day).round
      score += [ 10 - days_old, 0 ].max if days_old <= 10
    end

    self.qualification_score = [ score, 100 ].min
  end

  def track_status_changes
    if status_changed?
      case status
      when "contacted"
        self.update_column(:last_contacted_at, Time.current) if last_contacted_at.blank?
      when "converted"
        self.update_column(:last_interaction_at, Time.current)
      end
    end
  end
  
  def create_notification
    LeadCreatedNotification.create!(
      user: user,
      params: { lead_id: id }
    )
  rescue => e
    Rails.logger.error "Failed to create notification: #{e.message}"
  end
end
