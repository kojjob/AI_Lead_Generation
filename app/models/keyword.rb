class Keyword < ApplicationRecord
  self.inheritance_column = nil # Disable single-table inheritance

  belongs_to :user
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
  def mentions_count
    mentions.count
  end

  def leads_count
    leads.count
  end

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
end
