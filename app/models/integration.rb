class Integration < ApplicationRecord
  self.inheritance_column = nil # Disable single-table inheritance

  # Constants
  SUPPORTED_PLATFORMS = %w[twitter linkedin reddit facebook instagram slack discord].freeze
  
  SYNC_FREQUENCIES = {
    'realtime' => 1.minute,
    'every_5_minutes' => 5.minutes,
    'every_15_minutes' => 15.minutes,
    'every_30_minutes' => 30.minutes,
    'hourly' => 1.hour,
    'every_3_hours' => 3.hours,
    'every_6_hours' => 6.hours,
    'daily' => 1.day,
    'weekly' => 1.week
  }.freeze

  CONNECTION_STATUSES = %w[connected disconnected connecting error suspended rate_limited].freeze
  
  MAX_ERROR_COUNT = 5
  RATE_LIMIT_WINDOW = 15.minutes

  # Encryption for sensitive fields
  encrypts :api_key, deterministic: false
  encrypts :api_secret, deterministic: false
  encrypts :access_token, deterministic: false
  encrypts :refresh_token, deterministic: false
  encrypts :webhook_secret, deterministic: false

  # Associations
  belongs_to :user
  has_many :mentions, ->(integration) { where(platform: integration.platform_name) }, 
           foreign_key: :keyword_id, through: :user, source: :mentions
  has_many :integration_logs, dependent: :destroy

  # Validations
  validates :provider, presence: true, uniqueness: { scope: :user_id }
  validates :user, presence: true
  validates :platform_name, inclusion: { in: SUPPORTED_PLATFORMS, allow_blank: true }
  validates :sync_frequency, inclusion: { in: SYNC_FREQUENCIES.keys }
  validates :connection_status, inclusion: { in: CONNECTION_STATUSES }
  validates :error_count, numericality: { greater_than_or_equal_to: 0 }
  
  validate :validate_platform_credentials
  validate :validate_settings_format

  # Callbacks
  before_validation :set_default_values
  after_update :check_connection_health
  after_save :schedule_sync_job, if: :should_schedule_sync?

  # Scopes
  scope :active, -> { where(status: "active", enabled: true) }
  scope :enabled, -> { where(enabled: true) }
  scope :connected, -> { where(connection_status: 'connected') }
  scope :disconnected, -> { where(connection_status: 'disconnected') }
  scope :with_errors, -> { where('error_count > 0') }
  scope :needs_sync, -> { where('last_sync_at < ? OR last_sync_at IS NULL', 1.hour.ago) }
  scope :by_provider, ->(provider) { where(provider: provider) }
  scope :by_platform, ->(platform) { where(platform_name: platform) }
  scope :ready_for_sync, -> { active.connected.where('next_sync_at <= ? OR next_sync_at IS NULL', Time.current) }

  # Class methods
  def self.sync_all_ready
    ready_for_sync.find_each(&:sync!)
  end

  def self.check_all_connections
    enabled.find_each(&:check_connection!)
  end

  # Instance methods - Core functionality
  def active?
    status == "active" && enabled? && connected?
  end

  def connected?
    connection_status == 'connected'
  end

  def disconnected?
    connection_status == 'disconnected'
  end

  def error?
    connection_status == 'error' || error_count > 0
  end

  def rate_limited?
    connection_status == 'rate_limited' || 
    (rate_limit_remaining.present? && rate_limit_remaining <= 0 && rate_limit_reset_at&.future?)
  end

  def suspended?
    connection_status == 'suspended' || error_count >= MAX_ERROR_COUNT
  end

  # Connection management
  def connect!
    update!(connection_status: 'connecting')
    
    begin
      case platform_name
      when 'twitter'
        connect_twitter!
      when 'linkedin'
        connect_linkedin!
      when 'reddit'
        connect_reddit!
      when 'facebook'
        connect_facebook!
      else
        raise NotImplementedError, "Platform #{platform_name} is not yet implemented"
      end
      
      update!(
        connection_status: 'connected',
        error_count: 0,
        error_message: nil,
        last_successful_sync_at: Time.current
      )
      
      log_activity('connected', 'Successfully connected to platform')
      true
    rescue StandardError => e
      handle_connection_error(e)
      false
    end
  end

  def disconnect!
    update!(
      connection_status: 'disconnected',
      access_token: nil,
      refresh_token: nil,
      token_expires_at: nil
    )
    
    log_activity('disconnected', 'Disconnected from platform')
  end

  def check_connection!
    return false unless enabled?
    
    begin
      validate_authentication!
      update!(connection_status: 'connected', error_count: 0) unless connected?
      true
    rescue StandardError => e
      handle_connection_error(e)
      false
    end
  end

  # Synchronization
  def sync!
    return false unless can_sync?
    
    update!(last_sync_at: Time.current)
    
    begin
      IntegrationSyncJob.perform_later(self)
      log_activity('sync_started', 'Sync initiated')
      true
    rescue StandardError => e
      handle_sync_error(e)
      false
    end
  end

  def sync_now!
    return false unless can_sync?
    
    begin
      perform_sync
      update!(
        last_sync_at: Time.current,
        last_successful_sync_at: Time.current,
        error_count: 0,
        error_message: nil,
        connection_status: 'connected'
      )
      true
    rescue StandardError => e
      handle_sync_error(e)
      false
    end
  end

  def can_sync?
    enabled? && connected? && !rate_limited? && !suspended?
  end

  def next_sync_at
    return nil unless last_sync_at.present? && sync_frequency.present?
    
    last_sync_at + SYNC_FREQUENCIES[sync_frequency]
  end

  def sync_overdue?
    next_sync_at.present? && next_sync_at < Time.current
  end

  # Health monitoring
  def health_score
    return 0 unless active?

    score = 100

    # Connection status (30 points)
    score -= 30 unless connected?
    
    # Recent sync (25 points)
    if last_successful_sync_at
      hours_since_sync = (Time.current - last_successful_sync_at) / 1.hour
      score -= [hours_since_sync * 2, 25].min
    else
      score -= 25
    end
    
    # Error rate (25 points)
    score -= [error_count * 5, 25].min
    
    # Rate limiting (20 points)
    score -= 20 if rate_limited?
    
    [score, 0].max.round
  end

  def health_status
    case health_score
    when 90..100
      'excellent'
    when 70..89
      'good'
    when 50..69
      'fair'
    when 30..49
      'poor'
    else
      'critical'
    end
  end

  def sync_status
    return "never" unless last_sync_at

    hours_ago = (Time.current - last_sync_at) / 1.hour

    case hours_ago
    when 0..1
      "recent"
    when 1..24
      "today"
    when 24..168
      "this_week"
    else
      "old"
    end
  end

  # Statistics
  def mentions_count
    mentions.count
  end

  def leads_count
    user.leads.joins(mention: :keyword)
        .where(keywords: { id: user.keywords.where(platform: platform_name) })
        .count
  end

  def sync_success_rate
    return 0 if total_synced_items.zero?
    
    successful_syncs = integration_logs.where(activity_type: 'sync_completed').count
    total_syncs = integration_logs.where(activity_type: ['sync_completed', 'sync_failed']).count
    
    return 100 if total_syncs.zero?
    
    ((successful_syncs.to_f / total_syncs) * 100).round(2)
  end

  # Settings management
  def get_setting(key)
    settings&.dig(key.to_s)
  end

  def set_setting(key, value)
    self.settings ||= {}
    self.settings[key.to_s] = value
    save!
  end

  def update_settings(new_settings)
    self.settings ||= {}
    self.settings.merge!(new_settings.stringify_keys)
    save!
  end

  # Platform-specific methods
  def platform_client
    @platform_client ||= case platform_name
    when 'twitter'
      TwitterClient.new(self)
    when 'linkedin'
      LinkedInClient.new(self)
    when 'reddit'
      RedditClient.new(self)
    when 'facebook'
      FacebookClient.new(self)
    else
      raise NotImplementedError, "Client for #{platform_name} is not implemented"
    end
  end

  def refresh_access_token!
    return false unless refresh_token.present?
    
    begin
      platform_client.refresh_token!
      true
    rescue StandardError => e
      handle_connection_error(e)
      false
    end
  end

  private

  def set_default_values
    self.status ||= 'active'
    self.connection_status ||= 'disconnected'
    self.sync_frequency ||= 'hourly'
    self.error_count ||= 0
    self.total_synced_items ||= 0
    self.settings ||= {}
    self.metadata ||= {}
    self.enabled = true if enabled.nil?
  end

  def validate_platform_credentials
    return unless platform_name.present?
    
    case platform_name
    when 'twitter'
      errors.add(:api_key, "is required for Twitter") if api_key.blank?
      errors.add(:api_secret, "is required for Twitter") if api_secret.blank?
    when 'linkedin'
      errors.add(:api_key, "is required for LinkedIn") if api_key.blank?
      errors.add(:api_secret, "is required for LinkedIn") if api_secret.blank?
    when 'reddit'
      errors.add(:api_key, "is required for Reddit") if api_key.blank?
      errors.add(:api_secret, "is required for Reddit") if api_secret.blank?
    when 'facebook'
      errors.add(:access_token, "is required for Facebook") if access_token.blank?
    end
  end

  def validate_settings_format
    return if settings.blank?
    
    unless settings.is_a?(Hash)
      errors.add(:settings, "must be a valid JSON object")
    end
  end

  def validate_authentication!
    case platform_name
    when 'twitter', 'linkedin', 'reddit'
      raise "Access token expired" if token_expires_at.present? && token_expires_at < Time.current
      raise "Missing access token" if access_token.blank?
    when 'facebook'
      raise "Missing access token" if access_token.blank?
    end
  end

  def check_connection_health
    if error_count >= MAX_ERROR_COUNT && connection_status != 'suspended'
      update_column(:connection_status, 'suspended')
      log_activity('suspended', "Integration suspended after #{MAX_ERROR_COUNT} errors")
    end
  end

  def should_schedule_sync?
    saved_change_to_enabled? && enabled? && connected?
  end

  def schedule_sync_job
    IntegrationSyncJob.set(wait: 1.minute).perform_later(self)
  end

  def perform_sync
    platform_client.sync_mentions
  end

  def handle_connection_error(error)
    increment!(:error_count)
    update!(
      connection_status: 'error',
      error_message: error.message,
      last_error_at: Time.current
    )
    
    log_activity('connection_error', error.message)
    Rails.logger.error "[Integration #{id}] Connection error: #{error.message}"
  end

  def handle_sync_error(error)
    increment!(:error_count)
    update!(
      error_message: error.message,
      last_error_at: Time.current
    )
    
    log_activity('sync_failed', error.message)
    Rails.logger.error "[Integration #{id}] Sync error: #{error.message}"
  end

  def log_activity(activity_type, details = nil)
    integration_logs.create!(
      activity_type: activity_type,
      details: details,
      performed_at: Time.current
    ) if defined?(IntegrationLog)
  rescue StandardError => e
    Rails.logger.error "Failed to log activity: #{e.message}"
  end

  # Platform-specific connection methods
  def connect_twitter!
    # Implementation would go here
    raise NotImplementedError, "Twitter connection not yet implemented"
  end

  def connect_linkedin!
    # Implementation would go here
    raise NotImplementedError, "LinkedIn connection not yet implemented"
  end

  def connect_reddit!
    # Implementation would go here
    raise NotImplementedError, "Reddit connection not yet implemented"
  end

  def connect_facebook!
    # Implementation would go here
    raise NotImplementedError, "Facebook connection not yet implemented"
  end
end
