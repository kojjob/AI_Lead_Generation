class LeadQualityUpdateJob < ApplicationJob
  queue_as :ai_processing

  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(lead)
    Rails.logger.info "Updating quality prediction for lead #{lead.id}"

    # Update quality prediction
    prediction = lead.update_quality_prediction!

    # Update lead priority based on quality
    update_lead_priority(lead, prediction)

    # Create notification for high-quality leads
    notify_high_quality_lead(lead, prediction) if prediction[:quality_tier] == "high"

    Rails.logger.info "Successfully updated quality for lead #{lead.id}: #{prediction[:quality_tier]}"
  rescue StandardError => e
    Rails.logger.error "Failed to update lead quality for lead #{lead.id}: #{e.message}"
    raise e
  end

  private

  def update_lead_priority(lead, prediction)
    new_priority = case prediction[:quality_tier]
    when "high"
      "urgent"
    when "medium"
      "high"
    when "low"
      "medium"
    else
      "low"
    end

    lead.update!(priority: new_priority) if lead.priority != new_priority
  end

  def notify_high_quality_lead(lead, prediction)
    return unless lead.user.present?

    HighQualityLeadNotification.create!(
      user: lead.user,
      params: {
        lead_id: lead.id,
        quality_score: prediction[:quality_score],
        conversion_probability: prediction[:conversion_probability]
      }
    )
  rescue StandardError => e
    Rails.logger.error "Failed to create high quality lead notification: #{e.message}"
  end
end
