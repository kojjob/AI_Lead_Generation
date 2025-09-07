class IntegrationLog < ApplicationRecord
  # Constants
  ACTIVITY_TYPES = %w[
    connected disconnected connection_error suspended
    sync_started sync_completed sync_failed sync_error
    rate_limited token_refreshed webhook_received
    settings_updated enabled disabled
  ].freeze

  # Associations
  belongs_to :integration
  has_one :user, through: :integration

  # Validations
  validates :activity_type, presence: true, inclusion: { in: ACTIVITY_TYPES }
  validates :performed_at, presence: true

  # Callbacks
  before_validation :set_performed_at

  # Scopes
  scope :recent, -> { order(performed_at: :desc) }
  scope :by_type, ->(type) { where(activity_type: type) }
  scope :errors, -> { where(activity_type: %w[connection_error sync_failed sync_error suspended]) }
  scope :successful, -> { where(activity_type: %w[connected sync_completed token_refreshed]) }
  scope :for_period, ->(start_date, end_date) { where(performed_at: start_date..end_date) }

  # Class methods
  def self.cleanup_old_logs(days_to_keep = 30)
    where("performed_at < ?", days_to_keep.days.ago).destroy_all
  end

  # Instance methods
  def error?
    activity_type.in?(%w[connection_error sync_failed sync_error suspended])
  end

  def success?
    activity_type.in?(%w[connected sync_completed token_refreshed])
  end

  def sync_related?
    activity_type.start_with?("sync_")
  end

  private

  def set_performed_at
    self.performed_at ||= Time.current
  end
end
