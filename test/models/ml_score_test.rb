require "test_helper"

class MlScoreTest < ActiveSupport::TestCase
  def setup
    @ml_score = ml_scores(:one)
    @lead = leads(:one)
    @mention = mentions(:one)
    @ai_model = ai_models(:gpt_4_test)
  end

  # Validation Tests
  test "should be valid with valid attributes" do
    assert @ml_score.valid?
  end

  test "should require score" do
    @ml_score.score = nil
    assert_not @ml_score.valid?
    assert_includes @ml_score.errors[:score], "can't be blank"
  end

  test "should validate score between 0 and 1" do
    @ml_score.score = -0.1
    assert_not @ml_score.valid?
    assert_includes @ml_score.errors[:score], "must be greater than or equal to 0"

    @ml_score.score = 1.1
    assert_not @ml_score.valid?
    assert_includes @ml_score.errors[:score], "must be less than or equal to 1"

    @ml_score.score = 0.5
    assert @ml_score.valid?
  end

  test "should validate confidence between 0 and 1 when present" do
    @ml_score.confidence = -0.1
    assert_not @ml_score.valid?
    assert_includes @ml_score.errors[:confidence], "must be greater than or equal to 0"

    @ml_score.confidence = 1.1
    assert_not @ml_score.valid?
    assert_includes @ml_score.errors[:confidence], "must be less than or equal to 1"

    @ml_score.confidence = 0.9
    assert @ml_score.valid?

    @ml_score.confidence = nil
    assert @ml_score.valid?
  end

  test "should enforce unique constraint on ai_model and scoreable combination" do
    existing_score = MlScore.create!(
      scoreable: @lead,
      ai_model: @ai_model,
      score: 0.8,
      confidence: 0.9
    )

    duplicate_score = MlScore.new(
      scoreable: @lead,
      ai_model: @ai_model,
      score: 0.7,
      confidence: 0.8
    )

    assert_not duplicate_score.valid?
    assert_includes duplicate_score.errors[:ai_model_id], "has already been taken"
  end

  test "should allow same ai_model for different scoreables" do
    score1 = MlScore.create!(
      scoreable: @lead,
      ai_model: @ai_model,
      score: 0.8
    )

    score2 = MlScore.new(
      scoreable: @mention,
      ai_model: @ai_model,
      score: 0.7
    )

    assert score2.valid?
  end

  # Association Tests
  test "should belong to scoreable polymorphically" do
    assert_respond_to @ml_score, :scoreable
  end

  test "should work with Lead as scoreable" do
    ml_score = MlScore.new(
      scoreable: @lead,
      score: 0.85,
      confidence: 0.9
    )
    assert ml_score.valid?
    assert_equal @lead, ml_score.scoreable
    assert_equal "Lead", ml_score.scoreable_type
  end

  test "should work with Mention as scoreable" do
    ml_score = MlScore.new(
      scoreable: @mention,
      score: 0.75,
      confidence: 0.8
    )
    assert ml_score.valid?
    assert_equal @mention, ml_score.scoreable
    assert_equal "Mention", ml_score.scoreable_type
  end

  test "should belong to ai_model optionally" do
    @ml_score.ai_model = nil
    assert @ml_score.valid?

    @ml_score.ai_model = @ai_model
    assert @ml_score.valid?
    assert_equal @ai_model, @ml_score.ai_model
  end

  # Scope Tests
  test "by_model scope should filter by ai_model" do
    MlScore.destroy_all
    score1 = MlScore.create!(
      scoreable: @lead,
      ai_model: @ai_model,
      score: 0.8
    )
    score2 = MlScore.create!(
      scoreable: @mention,
      ai_model: ai_models(:claude_test),
      score: 0.7
    )

    scores = MlScore.by_model(@ai_model)
    assert_includes scores, score1
    assert_not_includes scores, score2
  end

  test "high_confidence scope should return scores with confidence > 0.8" do
    MlScore.destroy_all
    high_conf = MlScore.create!(
      scoreable: @lead,
      score: 0.9,
      confidence: 0.95
    )
    low_conf = MlScore.create!(
      scoreable: @mention,
      score: 0.9,
      confidence: 0.7
    )

    scores = MlScore.high_confidence
    assert_includes scores, high_conf
    assert_not_includes scores, low_conf
  end

  test "recent scope should order by created_at desc" do
    MlScore.destroy_all
    old_score = MlScore.create!(
      scoreable: @lead,
      score: 0.8,
      created_at: 2.days.ago
    )
    new_score = MlScore.create!(
      scoreable: @mention,
      score: 0.9,
      created_at: 1.hour.ago
    )

    scores = MlScore.recent
    assert_equal new_score, scores.first
    assert_equal old_score, scores.last
  end

  test "for_type scope should filter by scoreable_type" do
    MlScore.destroy_all
    lead_score = MlScore.create!(
      scoreable: @lead,
      score: 0.8
    )
    mention_score = MlScore.create!(
      scoreable: @mention,
      score: 0.7
    )

    lead_scores = MlScore.for_type("Lead")
    assert_includes lead_scores, lead_score
    assert_not_includes lead_scores, mention_score
  end

  # Method Tests
  test "should check high_confidence? correctly" do
    @ml_score.confidence = 0.85
    assert @ml_score.high_confidence?

    @ml_score.confidence = 0.79
    assert_not @ml_score.high_confidence?

    @ml_score.confidence = nil
    assert_not @ml_score.high_confidence?
  end

  test "should return model_name correctly" do
    @ml_score.ai_model = @ai_model
    assert_equal "GPT-4 Test", @ml_score.model_name

    @ml_score.ai_model = nil
    @ml_score.ml_model_name = "Custom Model"
    assert_equal "Custom Model", @ml_score.model_name

    @ml_score.ml_model_name = nil
    assert_equal "Unknown Model", @ml_score.model_name
  end

  test "should calculate score_percentage correctly" do
    @ml_score.score = 0.856
    assert_equal 85.6, @ml_score.score_percentage

    @ml_score.score = 1.0
    assert_equal 100.0, @ml_score.score_percentage

    @ml_score.score = 0.0
    assert_equal 0.0, @ml_score.score_percentage
  end

  test "should calculate confidence_percentage correctly" do
    @ml_score.confidence = 0.923
    assert_equal 92.3, @ml_score.confidence_percentage

    @ml_score.confidence = nil
    assert_nil @ml_score.confidence_percentage
  end

  # JSON Field Tests
  test "should store and retrieve features as JSON" do
    features = {
      "sentiment" => 0.8,
      "relevance" => 0.9,
      "entities" => [ "Company A", "Product B" ]
    }
    @ml_score.features = features
    @ml_score.save!
    @ml_score.reload

    assert_equal features, @ml_score.features
    assert_equal 0.8, @ml_score.features["sentiment"]
  end

  test "should store and retrieve predictions as JSON" do
    predictions = {
      "lead_quality" => "high",
      "conversion_probability" => 0.75,
      "recommended_actions" => [ "follow_up", "send_proposal" ]
    }
    @ml_score.predictions = predictions
    @ml_score.save!
    @ml_score.reload

    assert_equal predictions, @ml_score.predictions
    assert_equal "high", @ml_score.predictions["lead_quality"]
  end

  test "should store and retrieve metadata as JSON" do
    metadata = {
      "processing_time_ms" => 234,
      "model_version" => "1.0.2",
      "timestamp" => "2024-01-15T10:30:00Z"
    }
    @ml_score.metadata = metadata
    @ml_score.save!
    @ml_score.reload

    assert_equal metadata, @ml_score.metadata
    assert_equal 234, @ml_score.metadata["processing_time_ms"]
  end

  # Edge Cases
  test "should handle nil JSON fields gracefully" do
    @ml_score.features = nil
    @ml_score.predictions = nil
    @ml_score.metadata = nil

    assert @ml_score.valid?
    assert @ml_score.save
  end

  test "should handle empty JSON fields" do
    @ml_score.features = {}
    @ml_score.predictions = {}
    @ml_score.metadata = {}

    assert @ml_score.valid?
    assert @ml_score.save
  end
end
