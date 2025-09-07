class Integration < ApplicationRecord
  self.inheritance_column = nil # Disable single-table inheritance

  belongs_to :user
  # Note: mentions don't have a platform column in the current schema

  # Validations
  validates :provider, presence: true, uniqueness: { scope: :user_id }
  validates :user, presence: true

  # Scopes
  scope :active, -> { where(status: 'active') }
  scope :by_provider, ->(provider) { where(provider: provider) }

  # Instance methods
  def active?
    status == 'active'
  end

  def mentions_count
    # Since mentions don't have a platform column, return 0 for now
    # This would need to be implemented based on actual data structure
    0
  end

  def health_score
    return 0 unless active?

    score = 100

    # Deduct points for old last sync
    if last_searched_at
      days_since_sync = (Time.current - last_searched_at) / 1.day
      score -= [days_since_sync * 5, 50].min
    else
      score -= 50
    end

    [score, 0].max.round
  end

  def sync_status
    return 'never' unless last_searched_at

    hours_ago = (Time.current - last_searched_at) / 1.hour

    case hours_ago
    when 0..1
      'recent'
    when 1..24
      'today'
    when 24..168
      'this_week'
    else
      'old'
    end
  end
end
