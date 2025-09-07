class WebhookProcessorJob < ApplicationJob
  queue_as :webhooks
  
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(webhook)
    return unless webhook.pending?
    
    Rails.logger.info "Processing webhook #{webhook.id} for #{webhook.integration.platform_name}"
    
    webhook.process!
    
    # Update integration last sync time
    webhook.integration.update!(last_sync_at: Time.current)
    
    Rails.logger.info "Successfully processed webhook #{webhook.id}"
  rescue StandardError => e
    Rails.logger.error "Failed to process webhook #{webhook.id}: #{e.message}"
    webhook.mark_failed!(e.message)
    raise e
  end
end
