require "test_helper"

class AI::IntelligenceControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    @mention = mentions(:one)
    @lead = leads(:one)
    @ai_model = ai_models(:gpt_4_test)
    sign_in @user
  end

  # Index Tests
  test "should get index" do
    get ai_intelligence_index_url
    assert_response :success
    assert_not_nil assigns(:ai_models)
    assert_not_nil assigns(:recent_scores)
    assert_not_nil assigns(:search_indices)
  end

  test "should require authentication for index" do
    sign_out @user
    get ai_intelligence_index_url
    assert_redirected_to new_user_session_url
  end

  # Analyze Mention Tests
  test "should analyze mention successfully" do
    mock_result = {
      success: true,
      analysis: {
        sentiment: { score: 0.8, label: "positive" },
        entities: [ "Company A" ],
        intent: "purchase_inquiry",
        relevance_score: 0.85
      }
    }

    AI::EnhancedAnalysisService.any_instance.stub :analyze_mention, mock_result do
      post analyze_mention_ai_intelligence_index_url, params: {
        mention_id: @mention.id
      }

      assert_response :success
      json_response = JSON.parse(response.body)
      assert json_response["success"]
      assert_equal 0.8, json_response["analysis"]["sentiment"]["score"]
      assert_equal "positive", json_response["analysis"]["sentiment"]["label"]
    end
  end

  test "should handle mention analysis errors" do
    mock_result = {
      success: false,
      error: "API rate limit exceeded"
    }

    AI::EnhancedAnalysisService.any_instance.stub :analyze_mention, mock_result do
      post analyze_mention_ai_intelligence_index_url, params: {
        mention_id: @mention.id
      }

      assert_response :unprocessable_entity
      json_response = JSON.parse(response.body)
      assert_not json_response["success"]
      assert json_response["error"]
    end
  end

  test "should return 404 for non-existent mention" do
    post analyze_mention_ai_intelligence_index_url, params: {
      mention_id: 999999
    }

    assert_response :not_found
    json_response = JSON.parse(response.body)
    assert json_response["error"]
  end

  # Score Lead Tests
  test "should score lead successfully" do
    mock_result = {
      success: true,
      scoring: {
        lead_score: 0.88,
        confidence: 0.92,
        recommendation: "high_priority"
      }
    }

    AI::EnhancedAnalysisService.any_instance.stub :score_lead, mock_result do
      post score_lead_ai_intelligence_index_url, params: {
        lead_id: @lead.id
      }

      assert_response :success
      json_response = JSON.parse(response.body)
      assert json_response["success"]
      assert_equal 0.88, json_response["scoring"]["lead_score"]
      assert_equal "high_priority", json_response["scoring"]["recommendation"]
    end
  end

  test "should handle lead scoring errors" do
    mock_result = {
      success: false,
      error: "Model unavailable"
    }

    AI::EnhancedAnalysisService.any_instance.stub :score_lead, mock_result do
      post score_lead_ai_intelligence_index_url, params: {
        lead_id: @lead.id
      }

      assert_response :unprocessable_entity
      json_response = JSON.parse(response.body)
      assert_not json_response["success"]
      assert json_response["error"]
    end
  end

  # Batch Analyze Tests
  test "should batch analyze mentions" do
    mention_ids = [ @mention.id, mentions(:two).id ]

    mock_results = [
      { success: true, analysis: { sentiment: { score: 0.7 } } },
      { success: true, analysis: { sentiment: { score: 0.8 } } }
    ]

    AI::EnhancedAnalysisService.any_instance.stub :batch_analyze_mentions, mock_results do
      post batch_analyze_ai_intelligence_index_url, params: {
        mention_ids: mention_ids
      }

      assert_response :success
      json_response = JSON.parse(response.body)
      assert json_response["success"]
      assert_equal 2, json_response["results"].length
    end
  end

  test "should handle partial batch failures" do
    mention_ids = [ @mention.id, mentions(:two).id ]

    mock_results = [
      { success: true, analysis: { sentiment: { score: 0.7 } } },
      { success: false, error: "Processing failed" }
    ]

    AI::EnhancedAnalysisService.any_instance.stub :batch_analyze_mentions, mock_results do
      post batch_analyze_ai_intelligence_index_url, params: {
        mention_ids: mention_ids
      }

      assert_response :multi_status
      json_response = JSON.parse(response.body)
      assert json_response["partial_success"]
      assert_equal 1, json_response["succeeded"]
      assert_equal 1, json_response["failed"]
    end
  end

  test "should validate batch size limit" do
    mention_ids = (1..101).to_a  # Exceeds limit of 100

    post batch_analyze_ai_intelligence_index_url, params: {
      mention_ids: mention_ids
    }

    assert_response :bad_request
    json_response = JSON.parse(response.body)
    assert json_response["error"]
    assert_match /batch size/i, json_response["error"]
  end

  # Sentiment Analysis Tests
  test "should analyze sentiment of text" do
    mock_result = {
      success: true,
      sentiment: {
        sentiment: "positive",
        score: 0.85,
        confidence: 0.9
      }
    }

    AI::EnhancedAnalysisService.any_instance.stub :analyze_sentiment, mock_result do
      post analyze_sentiment_ai_intelligence_index_url, params: {
        text: "I love this product! It's amazing!",
        ai_model_id: @ai_model.id
      }

      assert_response :success
      json_response = JSON.parse(response.body)
      assert json_response["success"]
      assert_equal "positive", json_response["sentiment"]["sentiment"]
      assert_equal 0.85, json_response["sentiment"]["score"]
    end
  end

  test "should require text for sentiment analysis" do
    post analyze_sentiment_ai_intelligence_index_url, params: {
      text: "",
      ai_model_id: @ai_model.id
    }

    assert_response :bad_request
    json_response = JSON.parse(response.body)
    assert json_response["error"]
    assert_match /text is required/i, json_response["error"]
  end

  # Entity Extraction Tests
  test "should extract entities from text" do
    mock_result = {
      success: true,
      entities: {
        people: [ "John Smith" ],
        organizations: [ "Apple Inc." ],
        locations: [ "San Francisco" ]
      }
    }

    AI::EnhancedAnalysisService.any_instance.stub :extract_entities, mock_result do
      post extract_entities_ai_intelligence_index_url, params: {
        text: "John Smith from Apple Inc. in San Francisco",
        ai_model_id: @ai_model.id
      }

      assert_response :success
      json_response = JSON.parse(response.body)
      assert json_response["success"]
      assert_includes json_response["entities"]["people"], "John Smith"
      assert_includes json_response["entities"]["organizations"], "Apple Inc."
    end
  end

  # ML Score Tests
  test "should calculate ML score for entity" do
    mock_result = {
      success: true,
      score: 0.75,
      confidence: 0.88,
      prediction: "high_value"
    }

    AI::MlScoringService.any_instance.stub :calculate_lead_score, mock_result do
      post calculate_score_ai_intelligence_index_url, params: {
        entity_type: "Lead",
        entity_id: @lead.id,
        ai_model_id: @ai_model.id
      }

      assert_response :success
      json_response = JSON.parse(response.body)
      assert json_response["success"]
      assert_equal 0.75, json_response["score"]
      assert_equal 0.88, json_response["confidence"]
    end
  end

  test "should validate entity type for ML scoring" do
    post calculate_score_ai_intelligence_index_url, params: {
      entity_type: "InvalidType",
      entity_id: 1,
      ai_model_id: @ai_model.id
    }

    assert_response :bad_request
    json_response = JSON.parse(response.body)
    assert json_response["error"]
    assert_match /invalid entity type/i, json_response["error"]
  end

  # Search Index Tests
  test "should search mentions" do
    mock_results = {
      results: [
        { id: 1, content: "Test mention", score: 0.95 },
        { id: 2, content: "Another mention", score: 0.87 }
      ],
      total: 2
    }

    SearchIndex.any_instance.stub :search, mock_results do
      get search_ai_intelligence_index_url, params: {
        query: "test query",
        index_type: "mentions"
      }

      assert_response :success
      json_response = JSON.parse(response.body)
      assert_equal 2, json_response["results"].length
      assert_equal 2, json_response["total"]
    end
  end

  test "should require query for search" do
    get search_ai_intelligence_index_url, params: {
      query: "",
      index_type: "mentions"
    }

    assert_response :bad_request
    json_response = JSON.parse(response.body)
    assert json_response["error"]
    assert_match /query is required/i, json_response["error"]
  end

  # Sync Index Tests
  test "should sync search index" do
    search_index = search_indices(:one)

    SearchIndex.any_instance.stub :sync!, true do
      post sync_index_ai_intelligence_index_url, params: {
        index_id: search_index.id
      }

      assert_response :success
      json_response = JSON.parse(response.body)
      assert json_response["success"]
      assert_equal "Index sync initiated", json_response["message"]
    end
  end

  test "should handle sync failures" do
    search_index = search_indices(:one)

    SearchIndex.any_instance.stub :sync!, -> { raise StandardError, "Sync failed" } do
      post sync_index_ai_intelligence_index_url, params: {
        index_id: search_index.id
      }

      assert_response :internal_server_error
      json_response = JSON.parse(response.body)
      assert_not json_response["success"]
      assert json_response["error"]
    end
  end

  # Model Management Tests
  test "should list available AI models" do
    get models_ai_intelligence_index_url

    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response["models"]
    assert json_response["models"].length > 0

    first_model = json_response["models"].first
    assert first_model["id"]
    assert first_model["name"]
    assert first_model["provider"]
  end

  test "should get model details" do
    get model_ai_intelligence_url(@ai_model)

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal @ai_model.id, json_response["id"]
    assert_equal @ai_model.name, json_response["name"]
    assert_equal @ai_model.provider, json_response["provider"]
  end

  test "should handle non-existent model" do
    get model_ai_intelligence_url(id: 999999)

    assert_response :not_found
    json_response = JSON.parse(response.body)
    assert json_response["error"]
  end

  # Stats Tests
  test "should get AI intelligence stats" do
    get stats_ai_intelligence_index_url

    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response["total_scores"]
    assert json_response["average_confidence"]
    assert json_response["models_used"]
    assert json_response["recent_activity"]
  end

  # Authorization Tests
  test "should not allow unauthenticated access to analyze" do
    sign_out @user

    post analyze_mention_ai_intelligence_index_url, params: {
      mention_id: @mention.id
    }

    assert_redirected_to new_user_session_url
  end

  test "should not allow unauthenticated access to score" do
    sign_out @user

    post score_lead_ai_intelligence_index_url, params: {
      lead_id: @lead.id
    }

    assert_redirected_to new_user_session_url
  end

  # Parameter Validation Tests
  test "should validate AI model selection" do
    post analyze_sentiment_ai_intelligence_index_url, params: {
      text: "Test text",
      ai_model_id: 999999  # Non-existent model
    }

    assert_response :not_found
    json_response = JSON.parse(response.body)
    assert json_response["error"]
    assert_match /model not found/i, json_response["error"]
  end

  test "should use default model when not specified" do
    mock_result = {
      success: true,
      sentiment: { sentiment: "neutral", score: 0.5 }
    }

    AI::EnhancedAnalysisService.any_instance.stub :analyze_sentiment, mock_result do
      post analyze_sentiment_ai_intelligence_index_url, params: {
        text: "Test text"
        # No ai_model_id specified
      }

      assert_response :success
      json_response = JSON.parse(response.body)
      assert json_response["success"]
    end
  end
end
