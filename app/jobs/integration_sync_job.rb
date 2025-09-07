class IntegrationSyncJob < ApplicationJob
  queue_as :integrations

  # Retry configuration
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  retry_on Net::ReadTimeout, wait: 30.seconds, attempts: 5
  discard_on ActiveJob::DeserializationError

  def perform(integration)
    return unless integration.can_sync?

    Rails.logger.info "[IntegrationSyncJob] Starting sync for Integration ##{integration.id}"

    begin
      # Log sync start
      integration.log_activity("sync_started", "Background sync initiated")

      # Check rate limiting
      if integration.rate_limited?
        wait_time = integration.rate_limit_reset_at - Time.current
        Rails.logger.info "[IntegrationSyncJob] Rate limited. Retrying in #{wait_time} seconds"
        self.class.set(wait: wait_time).perform_later(integration)
        return
      end

      # Refresh token if needed
      if integration.token_expires_at.present? && integration.token_expires_at < 5.minutes.from_now
        integration.refresh_access_token!
      end

      # Perform the actual sync
      sync_results = perform_platform_sync(integration)

      # Update integration with results
      integration.update!(
        last_sync_at: Time.current,
        last_successful_sync_at: Time.current,
        total_synced_items: integration.total_synced_items + sync_results[:count],
        sync_cursor: sync_results[:cursor],
        error_count: 0,
        error_message: nil,
        connection_status: "connected"
      )

      # Log success
      integration.log_activity("sync_completed", "Synced #{sync_results[:count]} items")

      # Schedule next sync based on frequency
      schedule_next_sync(integration)

      Rails.logger.info "[IntegrationSyncJob] Completed sync for Integration ##{integration.id}"
    rescue StandardError => e
      handle_sync_error(integration, e)
      raise # Re-raise for retry mechanism
    end
  end

  private

  def perform_platform_sync(integration)
    case integration.platform_name
    when "twitter"
      sync_twitter_mentions(integration)
    when "linkedin"
      sync_linkedin_mentions(integration)
    when "reddit"
      sync_reddit_mentions(integration)
    when "facebook"
      sync_facebook_mentions(integration)
    else
      raise NotImplementedError, "Sync not implemented for #{integration.platform_name}"
    end
  end

  def sync_twitter_mentions(integration)
    # This would contain actual Twitter API integration
    # For now, return mock results
    { count: 0, cursor: nil, mentions: [] }
  end

  def sync_linkedin_mentions(integration)
    # This would contain actual LinkedIn API integration
    # For now, return mock results
    { count: 0, cursor: nil, mentions: [] }
  end

  def sync_reddit_mentions(integration)
    # This would contain actual Reddit API integration
    # For now, return mock results
    { count: 0, cursor: nil, mentions: [] }
  end

  def sync_facebook_mentions(integration)
    # This would contain actual Facebook API integration
    # For now, return mock results
    { count: 0, cursor: nil, mentions: [] }
  end

  def process_mentions(integration, mentions)
    mentions.each do |mention_data|
      # Find or create keyword based on mention
      keyword = find_or_create_keyword(integration, mention_data)

      # Create mention if it doesn't exist
      mention = keyword.mentions.find_or_initialize_by(
        platform: integration.platform_name,
        author: mention_data[:author],
        posted_at: mention_data[:posted_at]
      )

      mention.update!(
        content: mention_data[:content],
        raw_payload: mention_data[:raw],
        status: "active"
      )

      # Trigger analysis if new mention
      if mention.previously_new_record?
        AnalyzeMentionJob.perform_later(mention)
      end
    end
  end

  def find_or_create_keyword(integration, mention_data)
    # Logic to match mention to keyword or create new one
    integration.user.keywords.find_or_create_by(
      keyword: mention_data[:keyword] || "general",
      platform: integration.platform_name
    ) do |keyword|
      keyword.active = true
      keyword.status = "active"
    end
  end

  def schedule_next_sync(integration)
    return unless integration.sync_frequency.present?

    wait_time = Integration::SYNC_FREQUENCIES[integration.sync_frequency]
    self.class.set(wait: wait_time).perform_later(integration)

    Rails.logger.info "[IntegrationSyncJob] Next sync scheduled in #{wait_time} for Integration ##{integration.id}"
  end

  def handle_sync_error(integration, error)
    Rails.logger.error "[IntegrationSyncJob] Error syncing Integration ##{integration.id}: #{error.message}"
    Rails.logger.error error.backtrace.join("\n") if error.backtrace

    integration.increment!(:error_count)
    integration.update!(
      error_message: error.message,
      last_error_at: Time.current
    )

    # Mark as suspended if too many errors
    if integration.error_count >= Integration::MAX_ERROR_COUNT
      integration.update!(connection_status: "suspended")
      integration.log_activity("suspended", "Suspended after #{Integration::MAX_ERROR_COUNT} errors")

      # Notify user about suspension
      IntegrationMailer.suspension_notification(integration).deliver_later
    else
      integration.log_activity("sync_failed", error.message)
    end
  end
end
