module Ai
  class MlScoringService
    attr_reader :scoreable, :model_type, :options

    def initialize(scoreable, model_type, options = {})
      @scoreable = scoreable
      @model_type = model_type
      @options = options
    end

    def perform
      ai_model = select_ai_model
      return error_result("No AI model available for #{model_type}") unless ai_model

      features = extract_features
      score_data = calculate_score(ai_model, features)

      ml_score = create_or_update_score(ai_model, score_data)

      success_result(ml_score)
    rescue => e
      error_result(e.message)
    end

    private

    def select_ai_model
      AiModel.best_for(model_type, enabled_only: !options[:include_disabled])
    end

    def extract_features
      case scoreable
      when Lead
        extract_lead_features
      when Mention
        extract_mention_features
      when AnalysisResult
        extract_analysis_features
      else
        {}
      end
    end

    def extract_lead_features
      {
        values: {
          score: scoreable.score,
          status_weight: status_weight(scoreable.status),
          interaction_count: scoreable.interactions_count || 0,
          has_email: scoreable.email.present? ? 1 : 0,
          has_phone: scoreable.phone.present? ? 1 : 0,
          has_company: scoreable.company.present? ? 1 : 0,
          days_since_created: (Time.current - scoreable.created_at) / 1.day,
          urgency_indicator: urgency_score(scoreable),
          fit_score: fit_score(scoreable)
        },
        metadata: {
          source: scoreable.source,
          tags: scoreable.tags
        }
      }
    end

    def extract_mention_features
      {
        values: {
          content_length: scoreable.content.to_s.length,
          has_url: scoreable.source_url.present? ? 1 : 0,
          platform_weight: platform_weight(scoreable.platform),
          keyword_relevance: keyword_relevance(scoreable),
          engagement_metrics: scoreable.metadata["engagement"] || {},
          sentiment_indicator: sentiment_score(scoreable.content)
        },
        metadata: {
          platform: scoreable.platform,
          author: scoreable.author
        }
      }
    end

    def extract_analysis_features
      {
        values: {
          sentiment_score: sentiment_to_score(scoreable.sentiment),
          relevance_score: scoreable.relevance_score,
          confidence_score: scoreable.confidence_score,
          entity_count: scoreable.entities.to_a.length,
          topic_count: scoreable.topics.to_a.length,
          has_intent: scoreable.intent.present? ? 1 : 0,
          quality_score: quality_score(scoreable)
        },
        metadata: {
          ai_model: scoreable.ai_model_used,
          processing_time: scoreable.processing_time
        }
      }
    end

    def calculate_score(ai_model, features)
      case ai_model.provider
      when "openai"
        calculate_openai_score(ai_model, features)
      when "custom"
        calculate_custom_score(features)
      else
        calculate_rule_based_score(features)
      end
    end

    def calculate_openai_score(ai_model, features)
      client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])

      prompt = build_scoring_prompt(features)

      response = client.chat(
        parameters: {
          model: ai_model.name,
          messages: [
            { role: "system", content: scoring_system_prompt },
            { role: "user", content: prompt }
          ],
          **ai_model.configuration.symbolize_keys
        }
      )

      parse_ai_response(response)
    rescue => e
      Rails.logger.error "OpenAI scoring error: #{e.message}"
      calculate_rule_based_score(features)
    end

    def calculate_custom_score(features)
      # Custom ML model implementation
      weights = options[:weights] || default_weights

      score = features[:values].sum do |key, value|
        (weights[key] || 0.1) * normalize_value(value)
      end

      {
        score: score.clamp(0, 1),
        confidence: calculate_confidence(features),
        predictions: {
          quality: score > 0.7 ? "high" : score > 0.4 ? "medium" : "low",
          action_recommended: score > 0.6
        }
      }
    end

    def calculate_rule_based_score(features)
      values = features[:values]

      # Simple weighted scoring
      score = 0.0
      confidence = 0.5

      case model_type
      when "lead_scoring"
        score += 0.3 if values[:has_email] == 1
        score += 0.2 if values[:has_company] == 1
        score += 0.2 * (values[:fit_score] || 0.5)
        score += 0.15 * (values[:urgency_indicator] || 0.5)
        score += 0.15 * normalize_value(values[:interaction_count] || 0, max: 10)
        confidence = 0.7
      when "relevance_scoring"
        score = values[:relevance_score] || 0.5
        confidence = values[:confidence_score] || 0.6
      when "quality_assessment"
        score = values[:quality_score] || 0.5
        confidence = 0.6
      else
        score = 0.5
        confidence = 0.4
      end

      {
        score: score.clamp(0, 1),
        confidence: confidence,
        predictions: {
          category: score_category(score),
          threshold_passed: score > (options[:threshold] || 0.5)
        }
      }
    end

    def create_or_update_score(ai_model, score_data)
      ml_score = scoreable.ml_scores.find_or_initialize_by(
        ml_model_name: ai_model.name
      )

      ml_score.update!(
        ai_model: ai_model,
        score: score_data[:score],
        confidence: score_data[:confidence],
        features: extract_features,
        predictions: score_data[:predictions],
        metadata: {
          scored_at: Time.current,
          model_version: ai_model.version,
          options: options
        }
      )

      ai_model.increment_usage!

      ml_score
    end

    def scoring_system_prompt
      <<~PROMPT
        You are an AI scoring assistant. Analyze the provided features and return a score between 0 and 1.
        Consider all features holistically and provide:
        1. A numerical score (0-1)
        2. Confidence in your assessment (0-1)
        3. Key factors that influenced the score
        4. Recommendations for improvement

        Respond in JSON format.
      PROMPT
    end

    def build_scoring_prompt(features)
      <<~PROMPT
        Score the following #{model_type} with features:

        #{JSON.pretty_generate(features)}

        Provide a comprehensive scoring assessment.
      PROMPT
    end

    def parse_ai_response(response)
      content = response.dig("choices", 0, "message", "content")
      parsed = JSON.parse(content)

      {
        score: parsed["score"].to_f.clamp(0, 1),
        confidence: parsed["confidence"].to_f.clamp(0, 1),
        predictions: {
          factors: parsed["factors"],
          recommendations: parsed["recommendations"],
          summary: parsed["summary"]
        }
      }
    rescue
      calculate_rule_based_score(extract_features)
    end

    def status_weight(status)
      {
        "new" => 0.8,
        "contacted" => 0.6,
        "qualified" => 0.9,
        "converted" => 1.0,
        "lost" => 0.1
      }[status] || 0.5
    end

    def platform_weight(platform)
      {
        "twitter" => 0.7,
        "linkedin" => 0.9,
        "reddit" => 0.6,
        "facebook" => 0.5,
        "instagram" => 0.4
      }[platform&.downcase] || 0.5
    end

    def urgency_score(lead)
      # Calculate based on recent activity and signals
      recent_activity = lead.updated_at > 1.day.ago ? 0.3 : 0
      has_budget = lead.metadata&.dig("budget").present? ? 0.3 : 0
      timeline = lead.metadata&.dig("timeline") == "immediate" ? 0.4 : 0.2

      recent_activity + has_budget + timeline
    end

    def fit_score(lead)
      # Calculate product/market fit
      score = 0.5
      score += 0.2 if lead.metadata&.dig("industry_match")
      score += 0.15 if lead.metadata&.dig("size_match")
      score += 0.15 if lead.metadata&.dig("needs_match")
      score
    end

    def keyword_relevance(mention)
      return 0.5 unless mention.keyword.present?

      content = mention.content.to_s.downcase
      keyword = mention.keyword.term.downcase

      exact_matches = content.scan(/\b#{Regexp.escape(keyword)}\b/).count
      partial_matches = content.scan(/#{Regexp.escape(keyword)}/).count

      score = (exact_matches * 0.3 + partial_matches * 0.1).clamp(0, 1)
      score
    end

    def sentiment_score(content)
      # Simple sentiment scoring - would use NLP service in production
      positive_words = %w[great excellent amazing good fantastic love best perfect wonderful]
      negative_words = %w[bad terrible awful worst hate horrible poor disappointing frustrating]

      content_lower = content.to_s.downcase
      positive_count = positive_words.sum { |word| content_lower.scan(/\b#{word}\b/).count }
      negative_count = negative_words.sum { |word| content_lower.scan(/\b#{word}\b/).count }

      total = positive_count + negative_count
      return 0.5 if total == 0

      positive_count.to_f / total
    end

    def sentiment_to_score(sentiment)
      {
        "positive" => 0.8,
        "neutral" => 0.5,
        "negative" => 0.2,
        "mixed" => 0.5
      }[sentiment] || 0.5
    end

    def quality_score(analysis)
      score = 0.0
      score += 0.25 if analysis.summary.present? && analysis.summary.length > 50
      score += 0.25 if analysis.entities.present? && analysis.entities.any?
      score += 0.25 if analysis.relevance_score.to_f > 0.5
      score += 0.25 if analysis.confidence_score.to_f > 0.7
      score
    end

    def normalize_value(value, min: 0, max: 100)
      return 0 if value.nil?
      ((value.to_f - min) / (max - min)).clamp(0, 1)
    end

    def calculate_confidence(features)
      # Calculate confidence based on feature completeness
      values = features[:values]
      non_nil_count = values.values.compact.count
      total_count = values.count

      return 0.3 if total_count == 0

      (non_nil_count.to_f / total_count * 0.7 + 0.3).round(2)
    end

    def score_category(score)
      case score
      when 0...0.3 then "low"
      when 0.3...0.7 then "medium"
      when 0.7..1.0 then "high"
      end
    end

    def default_weights
      {
        score: 0.2,
        has_email: 0.15,
        has_company: 0.15,
        interaction_count: 0.1,
        urgency_indicator: 0.15,
        fit_score: 0.15,
        relevance_score: 0.1
      }
    end

    def success_result(ml_score)
      {
        success: true,
        ml_score: ml_score,
        score: ml_score.score,
        confidence: ml_score.confidence,
        category: ml_score.score_category
      }
    end

    def error_result(message)
      {
        success: false,
        error: message,
        ml_score: nil
      }
    end
  end
end
