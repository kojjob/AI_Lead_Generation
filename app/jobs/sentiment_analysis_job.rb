class SentimentAnalysisJob < ApplicationJob
  queue_as :ai_processing

  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(mention)
    Rails.logger.info "Analyzing sentiment for mention #{mention.id}"

    # Create or find analysis result
    analysis_result = mention.analysis_result || mention.build_analysis_result

    # Perform sentiment analysis
    sentiment_data = analysis_result.analyze_sentiment!

    # Extract entities and classify content
    analysis_result.extract_entities
    analysis_result.classify_content

    # Update related lead quality if exists
    if mention.lead
      LeadQualityUpdateJob.perform_later(mention.lead)
    end

    Rails.logger.info "Successfully analyzed sentiment for mention #{mention.id}: #{sentiment_data[:sentiment]}"
  rescue StandardError => e
    Rails.logger.error "Failed to analyze sentiment for mention #{mention.id}: #{e.message}"
    raise e
  end
end
