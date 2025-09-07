class BatchAiAnalysisJob < ApplicationJob
  queue_as :ai_processing

  retry_on StandardError, wait: :exponentially_longer, attempts: 2

  def perform(user_id, analysis_type = "all")
    user = User.find(user_id)
    Rails.logger.info "Starting batch AI analysis for user #{user.id}, type: #{analysis_type}"

    case analysis_type
    when "sentiment"
      analyze_sentiments(user)
    when "lead_quality"
      analyze_lead_quality(user)
    when "keywords"
      analyze_keywords(user)
    when "all"
      analyze_all(user)
    else
      Rails.logger.warn "Unknown analysis type: #{analysis_type}"
    end

    Rails.logger.info "Completed batch AI analysis for user #{user.id}"
  rescue StandardError => e
    Rails.logger.error "Failed batch AI analysis for user #{user_id}: #{e.message}"
    raise e
  end

  private

  def analyze_sentiments(user)
    mentions_without_analysis = user.mentions
                                   .left_joins(:analysis_result)
                                   .where(analysis_results: { id: nil })
                                   .limit(100) # Process in batches

    Rails.logger.info "Analyzing sentiment for #{mentions_without_analysis.count} mentions"

    mentions_without_analysis.find_each do |mention|
      SentimentAnalysisJob.perform_later(mention)
    end
  end

  def analyze_lead_quality(user)
    leads_needing_analysis = user.leads.needs_ai_analysis.limit(50)

    Rails.logger.info "Analyzing quality for #{leads_needing_analysis.count} leads"

    leads_needing_analysis.find_each do |lead|
      LeadQualityUpdateJob.perform_later(lead)
    end
  end

  def analyze_keywords(user)
    keywords = user.keywords.includes(:mentions, :leads)

    Rails.logger.info "Analyzing performance for #{keywords.count} keywords"

    keywords.each do |keyword|
      # Update keyword performance metrics
      keyword.update!(
        performance_score: keyword.performance_score,
        last_analyzed_at: Time.current
      )

      # Generate optimization suggestions
      suggestions = keyword.optimization_suggestions
      Rails.logger.info "Keyword '#{keyword.keyword}' suggestions: #{suggestions.join(', ')}"
    end
  end

  def analyze_all(user)
    analyze_sentiments(user)
    analyze_lead_quality(user)
    analyze_keywords(user)

    # Generate keyword recommendations
    recommendations = KeywordRecommendationService.generate_for_user(user, limit: 5)
    Rails.logger.info "Generated #{recommendations[:recommendations].count} keyword recommendations"

    # Create notification with insights
    create_analysis_summary_notification(user, recommendations)
  end

  def create_analysis_summary_notification(user, keyword_recommendations)
    # Calculate summary statistics
    total_leads = user.leads.count
    high_quality_leads = user.leads.where(quality_tier: "high").count
    avg_sentiment = user.mentions.joins(:analysis_result).average("analysis_results.sentiment_score") || 0

    summary = {
      total_leads: total_leads,
      high_quality_leads: high_quality_leads,
      quality_percentage: total_leads > 0 ? (high_quality_leads.to_f / total_leads * 100).round(1) : 0,
      average_sentiment: avg_sentiment.round(3),
      keyword_recommendations_count: keyword_recommendations[:recommendations].count,
      analysis_date: Time.current
    }

    AiAnalysisSummaryNotification.create!(
      user: user,
      params: summary
    )
  rescue StandardError => e
    Rails.logger.error "Failed to create analysis summary notification: #{e.message}"
  end
end
