class MlScore < ApplicationRecord
  belongs_to :scoreable, polymorphic: true
  belongs_to :ai_model, optional: true

  validates :ml_model_name, presence: true
  validates :score, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
  validates :confidence, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }, allow_nil: true

  scope :recent, -> { order(created_at: :desc) }
  scope :high_confidence, -> { where("confidence >= ?", 0.8) }
  scope :by_model, ->(model_name) { where(ml_model_name: model_name) }
  scope :above_threshold, ->(threshold) { where("score >= ?", threshold) }

  def high_confidence?
    confidence.present? && confidence >= 0.8
  end

  def score_category
    case score
    when 0...0.3 then :low
    when 0.3...0.7 then :medium
    when 0.7..1.0 then :high
    end
  end

  def score_label
    case score_category
    when :low then "Low"
    when :medium then "Medium"
    when :high then "High"
    end
  end

  def confidence_label
    return "Unknown" unless confidence.present?

    case confidence
    when 0...0.5 then "Low Confidence"
    when 0.5...0.8 then "Medium Confidence"
    when 0.8..1.0 then "High Confidence"
    end
  end

  def feature_importance
    features["importance"] || {}
  end

  def top_features(limit = 5)
    return [] unless features["values"].present?

    features["values"]
      .sort_by { |_, v| -v.to_f }
      .first(limit)
      .to_h
  end

  def prediction_summary
    predictions["summary"] || predictions["main"] || {}
  end

  def update_metrics(new_score, new_confidence = nil)
    update(
      score: new_score,
      confidence: new_confidence || confidence,
      metadata: metadata.merge(
        "updated_at" => Time.current,
        "previous_score" => score,
        "previous_confidence" => confidence
      )
    )
  end
end
