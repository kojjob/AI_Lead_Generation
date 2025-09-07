class Webhook < ApplicationRecord
  belongs_to :integration

  # Status constants
  STATUSES = %w[pending processing processed failed].freeze

  # Validations
  validates :event_type, presence: true
  validates :payload, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :retry_count, numericality: { greater_than_or_equal_to: 0 }

  # Scopes
  scope :pending, -> { where(status: "pending") }
  scope :processing, -> { where(status: "processing") }
  scope :processed, -> { where(status: "processed") }
  scope :failed, -> { where(status: "failed") }
  scope :ready_for_retry, -> { where("next_retry_at <= ? AND retry_count < ?", Time.current, 3) }
  scope :recent, -> { order(created_at: :desc) }

  # Callbacks
  before_create :set_initial_status
  after_create :enqueue_processing

  # Instance methods
  def process!
    return if processed?

    update!(status: "processing", processed_at: Time.current)

    begin
      case integration.platform_name
      when "instagram"
        process_instagram_webhook
      when "tiktok"
        process_tiktok_webhook
      when "salesforce"
        process_salesforce_webhook
      when "hubspot"
        process_hubspot_webhook
      when "pipedrive"
        process_pipedrive_webhook
      else
        process_generic_webhook
      end

      update!(status: "processed")
      Rails.logger.info "Webhook #{id} processed successfully"
    rescue StandardError => e
      handle_processing_error(e)
    end
  end

  def retry!
    return if retry_count >= 3

    increment!(:retry_count)
    update!(
      status: "pending",
      next_retry_at: calculate_next_retry_time,
      error_message: nil
    )

    enqueue_processing
  end

  def mark_failed!(error_message)
    update!(
      status: "failed",
      error_message: error_message,
      processed_at: Time.current
    )
  end

  def pending?
    status == "pending"
  end

  def processing?
    status == "processing"
  end

  def processed?
    status == "processed"
  end

  def failed?
    status == "failed"
  end

  def parsed_payload
    @parsed_payload ||= JSON.parse(payload) rescue {}
  end

  def parsed_headers
    headers || {}
  end

  private

  def set_initial_status
    self.status ||= "pending"
  end

  def enqueue_processing
    WebhookProcessorJob.perform_later(self) if Rails.env.production?
  end

  def process_instagram_webhook
    case event_type
    when "mentions"
      process_instagram_mention
    when "comments"
      process_instagram_comment
    when "stories"
      process_instagram_story
    else
      Rails.logger.warn "Unknown Instagram webhook event: #{event_type}"
    end
  end

  def process_tiktok_webhook
    case event_type
    when "mentions"
      process_tiktok_mention
    when "comments"
      process_tiktok_comment
    when "videos"
      process_tiktok_video
    else
      Rails.logger.warn "Unknown TikTok webhook event: #{event_type}"
    end
  end

  def process_salesforce_webhook
    case event_type
    when "lead_created", "lead_updated"
      process_salesforce_lead
    else
      Rails.logger.warn "Unknown Salesforce webhook event: #{event_type}"
    end
  end

  def process_hubspot_webhook
    case event_type
    when "contact_created", "contact_updated"
      process_hubspot_contact
    when "deal_created"
      process_hubspot_deal
    else
      Rails.logger.warn "Unknown HubSpot webhook event: #{event_type}"
    end
  end

  def process_pipedrive_webhook
    case event_type
    when "person_added", "person_updated"
      process_pipedrive_person
    when "deal_added"
      process_pipedrive_deal
    else
      Rails.logger.warn "Unknown Pipedrive webhook event: #{event_type}"
    end
  end

  def process_generic_webhook
    Rails.logger.info "Processing generic webhook for #{integration.platform_name}"
    # Generic webhook processing logic
  end

  def process_instagram_mention
    # Instagram mention processing logic
    Rails.logger.info "Processing Instagram mention webhook"
  end

  def process_instagram_comment
    # Instagram comment processing logic
    Rails.logger.info "Processing Instagram comment webhook"
  end

  def process_instagram_story
    # Instagram story processing logic
    Rails.logger.info "Processing Instagram story webhook"
  end

  def process_tiktok_mention
    # TikTok mention processing logic
    Rails.logger.info "Processing TikTok mention webhook"
  end

  def process_tiktok_comment
    # TikTok comment processing logic
    Rails.logger.info "Processing TikTok comment webhook"
  end

  def process_tiktok_video
    # TikTok video processing logic
    Rails.logger.info "Processing TikTok video webhook"
  end

  def process_salesforce_lead
    # Salesforce lead processing logic
    Rails.logger.info "Processing Salesforce lead webhook"
  end

  def process_hubspot_contact
    # HubSpot contact processing logic
    Rails.logger.info "Processing HubSpot contact webhook"
  end

  def process_hubspot_deal
    # HubSpot deal processing logic
    Rails.logger.info "Processing HubSpot deal webhook"
  end

  def process_pipedrive_person
    # Pipedrive person processing logic
    Rails.logger.info "Processing Pipedrive person webhook"
  end

  def process_pipedrive_deal
    # Pipedrive deal processing logic
    Rails.logger.info "Processing Pipedrive deal webhook"
  end

  def handle_processing_error(error)
    Rails.logger.error "Webhook #{id} processing failed: #{error.message}"

    if retry_count < 3
      update!(
        status: "pending",
        error_message: error.message,
        next_retry_at: calculate_next_retry_time
      )
      increment!(:retry_count)
    else
      mark_failed!(error.message)
    end
  end

  def calculate_next_retry_time
    # Exponential backoff: 1 minute, 5 minutes, 15 minutes
    delay_minutes = [ 1, 5, 15 ][retry_count] || 15
    delay_minutes.minutes.from_now
  end
end
