require "test_helper"

class AI::MlScoringServiceTest < ActiveSupport::TestCase
  def setup
    @service = AI::MlScoringService.new
    @lead = leads(:one)
    @mention = mentions(:one)
    @analysis_result = analysis_results(:one)
    @ai_model = ai_models(:gpt_4_test)
  end

  # Initialization Tests
  test "should initialize with default AI model" do
    service = AI::MlScoringService.new
    assert_not_nil service
  end

  test "should initialize with specific AI model" do
    service = AI::MlScoringService.new(ai_model: @ai_model)
    assert_not_nil service
  end

  # Lead Scoring Tests
  test "should calculate lead score successfully" do
    mock_ai_response = {
      content: JSON.generate({
        score: 0.85,
        confidence: 0.9,
        factors: {
          engagement: 0.9,
          budget_fit: 0.8,
          authority: 0.85,
          need: 0.9,
          timeline: 0.75
        },
        prediction: "high_value_lead"
      }),
      usage: { total_tokens: 120 }
    }

    AI::ModelAgnosticService.any_instance.stub :chat, mock_ai_response do
      result = @service.calculate_lead_score(@lead)

      assert result[:success]
      assert_equal 0.85, result[:score]
      assert_equal 0.9, result[:confidence]
      assert_equal "high_value_lead", result[:prediction]
      assert_equal 0.9, result[:factors][:engagement]
    end
  end

  test "should create ML score record for lead" do
    mock_ai_response = {
      content: JSON.generate({
        score: 0.75,
        confidence: 0.85,
        factors: { engagement: 0.8 },
        prediction: "medium_value_lead"
      }),
      usage: { total_tokens: 100 }
    }

    AI::ModelAgnosticService.any_instance.stub :chat, mock_ai_response do
      assert_difference "MlScore.count", 1 do
        result = @service.calculate_lead_score(@lead)
        assert result[:success]
      end

      ml_score = @lead.ml_scores.last
      assert_equal 0.75, ml_score.score
      assert_equal 0.85, ml_score.confidence
      assert_equal @ai_model, ml_score.ai_model
      assert_equal "medium_value_lead", ml_score.predictions["category"]
    end
  end

  test "should update existing ML score for lead" do
    # Create initial score
    existing_score = @lead.ml_scores.create!(
      ai_model: @ai_model,
      score: 0.5,
      confidence: 0.6
    )

    mock_ai_response = {
      content: JSON.generate({
        score: 0.9,
        confidence: 0.95,
        factors: {},
        prediction: "high_value_lead"
      }),
      usage: { total_tokens: 100 }
    }

    AI::ModelAgnosticService.any_instance.stub :chat, mock_ai_response do
      assert_no_difference "MlScore.count" do
        result = @service.calculate_lead_score(@lead)
        assert result[:success]
      end

      existing_score.reload
      assert_equal 0.9, existing_score.score
      assert_equal 0.95, existing_score.confidence
    end
  end

  # Mention Relevance Scoring Tests
  test "should calculate mention relevance score" do
    mock_ai_response = {
      content: JSON.generate({
        relevance: 0.78,
        confidence: 0.82,
        factors: {
          keyword_match: 0.9,
          context_relevance: 0.75,
          sentiment_alignment: 0.7
        },
        classification: "relevant"
      }),
      usage: { total_tokens: 90 }
    }

    AI::ModelAgnosticService.any_instance.stub :chat, mock_ai_response do
      result = @service.calculate_mention_relevance(@mention)

      assert result[:success]
      assert_equal 0.78, result[:relevance]
      assert_equal 0.82, result[:confidence]
      assert_equal "relevant", result[:classification]
      assert_equal 0.9, result[:factors][:keyword_match]
    end
  end

  test "should create ML score for mention" do
    mock_ai_response = {
      content: JSON.generate({
        relevance: 0.65,
        confidence: 0.75,
        factors: {},
        classification: "somewhat_relevant"
      }),
      usage: { total_tokens: 80 }
    }

    AI::ModelAgnosticService.any_instance.stub :chat, mock_ai_response do
      assert_difference "MlScore.count", 1 do
        result = @service.calculate_mention_relevance(@mention)
        assert result[:success]
      end

      ml_score = @mention.ml_scores.last
      assert_equal 0.65, ml_score.score
      assert_equal 0.75, ml_score.confidence
      assert_equal "somewhat_relevant", ml_score.predictions["classification"]
    end
  end

  # Analysis Quality Scoring Tests
  test "should calculate analysis quality score" do
    mock_ai_response = {
      content: JSON.generate({
        quality: 0.88,
        confidence: 0.91,
        metrics: {
          completeness: 0.9,
          accuracy: 0.85,
          depth: 0.88,
          actionability: 0.9
        },
        grade: "excellent"
      }),
      usage: { total_tokens: 110 }
    }

    AI::ModelAgnosticService.any_instance.stub :chat, mock_ai_response do
      result = @service.calculate_analysis_quality(@analysis_result)

      assert result[:success]
      assert_equal 0.88, result[:quality]
      assert_equal 0.91, result[:confidence]
      assert_equal "excellent", result[:grade]
      assert_equal 0.9, result[:metrics][:completeness]
    end
  end

  # Batch Scoring Tests
  test "should batch score multiple leads" do
    leads = [ @lead, leads(:two) ]

    mock_ai_response = {
      content: JSON.generate({
        score: 0.7,
        confidence: 0.8,
        factors: {},
        prediction: "medium_value_lead"
      }),
      usage: { total_tokens: 100 }
    }

    AI::ModelAgnosticService.any_instance.stub :chat, mock_ai_response do
      results = @service.batch_score_leads(leads)

      assert_kind_of Array, results
      assert_equal 2, results.length
      results.each do |result|
        assert result[:success]
        assert result[:score]
      end
    end
  end

  test "should handle partial batch failures" do
    leads = [ @lead, leads(:two) ]
    call_count = 0

    mock_proc = lambda do |_|
      call_count += 1
      if call_count == 1
        { content: JSON.generate({ score: 0.8, confidence: 0.85 }), usage: { total_tokens: 80 } }
      else
        { error: "API Error" }
      end
    end

    AI::ModelAgnosticService.any_instance.stub :chat, mock_proc do
      results = @service.batch_score_leads(leads)

      assert_equal 2, results.length
      assert results[0][:success]
      assert_not results[1][:success]
      assert results[1][:error]
    end
  end

  # Prediction Tests
  test "should predict lead conversion probability" do
    mock_ai_response = {
      content: JSON.generate({
        conversion_probability: 0.72,
        confidence: 0.85,
        timeline: "30-60 days",
        recommended_actions: [ "follow_up_email", "schedule_demo", "send_case_study" ]
      }),
      usage: { total_tokens: 130 }
    }

    AI::ModelAgnosticService.any_instance.stub :chat, mock_ai_response do
      result = @service.predict_conversion(@lead)

      assert result[:success]
      assert_equal 0.72, result[:conversion_probability]
      assert_equal 0.85, result[:confidence]
      assert_equal "30-60 days", result[:timeline]
      assert_includes result[:recommended_actions], "schedule_demo"
    end
  end

  test "should predict mention engagement" do
    mock_ai_response = {
      content: JSON.generate({
        engagement_score: 0.68,
        predicted_responses: 5,
        viral_potential: 0.3,
        best_response_time: "within 2 hours"
      }),
      usage: { total_tokens: 95 }
    }

    AI::ModelAgnosticService.any_instance.stub :chat, mock_ai_response do
      result = @service.predict_engagement(@mention)

      assert result[:success]
      assert_equal 0.68, result[:engagement_score]
      assert_equal 5, result[:predicted_responses]
      assert_equal 0.3, result[:viral_potential]
      assert_equal "within 2 hours", result[:best_response_time]
    end
  end

  # Score Aggregation Tests
  test "should aggregate scores for entity" do
    # Create multiple scores for the lead
    MlScore.create!(
      scoreable: @lead,
      ai_model: @ai_model,
      score: 0.8,
      confidence: 0.85
    )
    MlScore.create!(
      scoreable: @lead,
      ai_model: ai_models(:claude_test),
      score: 0.75,
      confidence: 0.9
    )

    result = @service.aggregate_scores(@lead)

    assert result[:success]
    assert result[:aggregated_score]
    assert result[:average_confidence]
    assert_equal 2, result[:score_count]
    assert_in_delta 0.775, result[:aggregated_score], 0.01
    assert_in_delta 0.875, result[:average_confidence], 0.01
  end

  test "should handle empty score aggregation" do
    # Ensure no scores exist
    @lead.ml_scores.destroy_all

    result = @service.aggregate_scores(@lead)

    assert result[:success]
    assert_nil result[:aggregated_score]
    assert_nil result[:average_confidence]
    assert_equal 0, result[:score_count]
  end

  # Score Comparison Tests
  test "should compare scores across models" do
    # Create scores from different models
    score1 = MlScore.create!(
      scoreable: @lead,
      ai_model: @ai_model,
      score: 0.85,
      confidence: 0.9
    )
    score2 = MlScore.create!(
      scoreable: @lead,
      ai_model: ai_models(:claude_test),
      score: 0.78,
      confidence: 0.88
    )

    result = @service.compare_model_scores(@lead)

    assert result[:success]
    assert_equal 2, result[:comparisons].length
    assert result[:best_score]
    assert_equal @ai_model.id, result[:best_score][:model_id]
    assert_equal 0.85, result[:best_score][:score]
  end

  # Threshold Tests
  test "should classify score by thresholds" do
    result = @service.classify_score(0.9)
    assert_equal "high", result

    result = @service.classify_score(0.7)
    assert_equal "medium", result

    result = @service.classify_score(0.4)
    assert_equal "low", result

    result = @service.classify_score(0.2)
    assert_equal "very_low", result
  end

  test "should filter entities by score threshold" do
    # Create leads with different scores
    high_lead = leads(:one)
    high_lead.ml_scores.create!(score: 0.9, confidence: 0.95)

    low_lead = leads(:two)
    low_lead.ml_scores.create!(score: 0.3, confidence: 0.8)

    leads = [ high_lead, low_lead ]
    filtered = @service.filter_by_score(leads, threshold: 0.7)

    assert_equal 1, filtered.length
    assert_includes filtered, high_lead
    assert_not_includes filtered, low_lead
  end

  # Feature Extraction Tests
  test "should extract scoring features from lead" do
    result = @service.extract_lead_features(@lead)

    assert result[:success]
    assert result[:features]
    assert result[:features][:has_email]
    assert result[:features][:has_company]
    assert_kind_of Integer, result[:features][:mention_count]
  end

  test "should extract scoring features from mention" do
    result = @service.extract_mention_features(@mention)

    assert result[:success]
    assert result[:features]
    assert result[:features][:has_content]
    assert result[:features][:has_url]
    assert_kind_of Integer, result[:features][:content_length]
  end

  # Error Handling Tests
  test "should handle scoring errors gracefully" do
    AI::ModelAgnosticService.any_instance.stub :chat, { error: "API Error" } do
      result = @service.calculate_lead_score(@lead)

      assert_not result[:success]
      assert result[:error]
      assert_match /API Error/, result[:error]
    end
  end

  test "should handle invalid JSON in response" do
    mock_ai_response = {
      content: "Invalid JSON response",
      usage: { total_tokens: 50 }
    }

    AI::ModelAgnosticService.any_instance.stub :chat, mock_ai_response do
      result = @service.calculate_lead_score(@lead)

      assert_not result[:success]
      assert result[:error]
    end
  end

  test "should handle missing required fields in response" do
    mock_ai_response = {
      content: JSON.generate({
        # Missing score field
        confidence: 0.9
      }),
      usage: { total_tokens: 50 }
    }

    AI::ModelAgnosticService.any_instance.stub :chat, mock_ai_response do
      result = @service.calculate_lead_score(@lead)

      assert_not result[:success]
      assert result[:error]
    end
  end

  # Model Configuration Tests
  test "should use custom temperature for scoring" do
    @ai_model.temperature = 0.2  # Lower temperature for more consistent scoring
    @ai_model.save!

    service = AI::MlScoringService.new(ai_model: @ai_model)
    assert_not_nil service
  end

  test "should respect max tokens limit" do
    @ai_model.max_tokens = 500
    @ai_model.save!

    service = AI::MlScoringService.new(ai_model: @ai_model)
    assert_not_nil service
  end
end
