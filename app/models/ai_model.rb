class AiModel < ApplicationRecord
  has_many :ml_scores, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :provider }
  validates :model_type, presence: true
  validates :provider, presence: true

  scope :enabled, -> { where(enabled: true) }
  scope :by_type, ->(type) { where(model_type: type) }
  scope :by_provider, ->(provider) { where(provider: provider) }
  scope :ordered_by_priority, -> { order(priority: :desc, created_at: :desc) }

  PROVIDERS = %w[openai anthropic gemini huggingface cohere custom].freeze

  MODEL_TYPES = %w[
    text_classification
    sentiment_analysis
    entity_extraction
    lead_scoring
    intent_detection
    relevance_scoring
    quality_assessment
    language_detection
    summarization
    embedding
  ].freeze

  CAPABILITIES = {
    text_classification: %w[multi_label binary hierarchical],
    sentiment_analysis: %w[polarity emotion aspect_based],
    entity_extraction: %w[named_entities keywords topics],
    lead_scoring: %w[quality urgency fit_score],
    intent_detection: %w[purchase_intent support_intent information_seeking],
    relevance_scoring: %w[semantic_similarity keyword_matching],
    quality_assessment: %w[content_quality credibility spam_detection],
    language_detection: %w[primary_language multi_language],
    summarization: %w[extractive abstractive],
    embedding: %w[text_embedding semantic_search clustering]
  }.freeze

  def self.best_for(model_type, enabled_only: true)
    scope = enabled_only ? enabled : all
    scope.by_type(model_type).ordered_by_priority.first
  end

  def self.create_default_models!
    default_models.each do |attrs|
      find_or_create_by(name: attrs[:name], provider: attrs[:provider]) do |model|
        model.assign_attributes(attrs)
      end
    end
  end

  def increment_usage!
    increment!(:usage_count)
    touch(:last_used_at)
  end

  def calculate_performance_score
    return 0.5 unless performance_metrics.present?

    weights = {
      "accuracy" => 0.3,
      "speed" => 0.2,
      "cost_efficiency" => 0.2,
      "reliability" => 0.3
    }

    score = weights.sum do |metric, weight|
      (performance_metrics[metric] || 0.5) * weight
    end

    score.round(3)
  end

  def update_performance_metrics(new_metrics)
    merged_metrics = performance_metrics.merge(new_metrics)
    merged_metrics["last_updated"] = Time.current
    merged_metrics["performance_score"] = calculate_performance_score

    update(performance_metrics: merged_metrics)
  end

  def cost_per_request
    return 0 unless pricing["per_request"].present?
    pricing["per_request"].to_f
  end

  def cost_per_token
    return 0 unless pricing["per_token"].present?
    pricing["per_token"].to_f
  end

  def supports_capability?(capability)
    return false unless capabilities[model_type].present?
    capabilities[model_type].include?(capability.to_s)
  end

  def api_config
    {
      provider: provider,
      model: name,
      version: version,
      **configuration.symbolize_keys
    }
  end

  private

  def self.default_models
    [
      {
        name: "gpt-4-turbo-preview",
        model_type: "text_classification",
        provider: "openai",
        version: "2024-01",
        description: "Advanced text classification with GPT-4",
        enabled: true,
        priority: 100,
        configuration: {
          temperature: 0.3,
          max_tokens: 2000,
          top_p: 0.9
        },
        capabilities: CAPABILITIES[:text_classification],
        pricing: { per_request: 0.03, per_token: 0.00003 }
      },
      {
        name: "gpt-4-turbo-preview",
        model_type: "lead_scoring",
        provider: "openai",
        version: "2024-01",
        description: "Intelligent lead scoring with GPT-4",
        enabled: true,
        priority: 100,
        configuration: {
          temperature: 0.2,
          max_tokens: 1500,
          functions: [ "score_lead", "extract_signals" ]
        },
        capabilities: CAPABILITIES[:lead_scoring],
        pricing: { per_request: 0.03, per_token: 0.00003 }
      },
      {
        name: "text-embedding-3-small",
        model_type: "embedding",
        provider: "openai",
        version: "3",
        description: "Fast and efficient text embeddings",
        enabled: true,
        priority: 90,
        configuration: {
          dimensions: 1536,
          encoding_format: "float"
        },
        capabilities: CAPABILITIES[:embedding],
        pricing: { per_token: 0.00002 }
      },
      {
        name: "claude-3-opus",
        model_type: "sentiment_analysis",
        provider: "anthropic",
        version: "3",
        description: "Deep sentiment analysis with Claude",
        enabled: false,
        priority: 95,
        configuration: {
          max_tokens: 1000,
          temperature: 0.3
        },
        capabilities: CAPABILITIES[:sentiment_analysis],
        pricing: { per_request: 0.015, per_token: 0.000015 }
      },
      {
        name: "gemini-pro",
        model_type: "entity_extraction",
        provider: "gemini",
        version: "1.0",
        description: "Entity extraction with Gemini",
        enabled: false,
        priority: 85,
        configuration: {
          candidate_count: 1,
          temperature: 0.2
        },
        capabilities: CAPABILITIES[:entity_extraction],
        pricing: { per_request: 0.01, per_token: 0.00001 }
      }
    ]
  end
end
