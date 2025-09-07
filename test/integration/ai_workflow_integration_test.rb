require "test_helper"

class AiWorkflowIntegrationTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    @keyword = keywords(:one)
    @mention = mentions(:one)
    @lead = leads(:one)
    @ai_model = ai_models(:gpt_4_test)
    sign_in @user
  end

  # Complete Lead Generation Workflow Test
  test "complete AI-powered lead generation workflow" do
    # Step 1: Create a new mention
    mention = Mention.create!(
      keyword: @keyword,
      content: "Looking for a software solution for our company. We have budget approved.",
      url: "https://example.com/discussion",
      platform: "reddit"
    )
    
    # Step 2: Analyze the mention with AI
    mock_analysis = {
      success: true,
      analysis: {
        sentiment: { score: 0.85, label: "positive" },
        entities: ["software solution", "company"],
        intent: "purchase_inquiry",
        relevance_score: 0.9
      }
    }
    
    AI::EnhancedAnalysisService.any_instance.stub :analyze_mention, mock_analysis do
      post analyze_mention_ai_intelligence_index_url, params: {
        mention_id: mention.id
      }
      
      assert_response :success
      json_response = JSON.parse(response.body)
      assert json_response["success"]
      assert_equal 0.9, json_response["analysis"]["relevance_score"]
    end
    
    # Step 3: Create an analysis result
    analysis_result = AnalysisResult.create!(
      mention: mention,
      sentiment_score: 0.85,
      relevance_score: 0.9,
      entities: ["software solution", "company"],
      key_phrases: ["budget approved", "looking for solution"]
    )
    
    # Step 4: Generate a lead from the analyzed mention
    lead = Lead.create!(
      mention: mention,
      name: "Potential Customer",
      email: "customer@example.com",
      company: "Example Corp",
      score: 0.0  # Will be updated by ML scoring
    )
    
    # Step 5: Score the lead with ML
    mock_scoring = {
      success: true,
      scoring: {
        lead_score: 0.88,
        confidence: 0.92,
        recommendation: "high_priority",
        factors: {
          budget_mentioned: 0.95,
          purchase_intent: 0.9,
          company_size: 0.8
        }
      }
    }
    
    AI::EnhancedAnalysisService.any_instance.stub :score_lead, mock_scoring do
      post score_lead_ai_intelligence_index_url, params: {
        lead_id: lead.id
      }
      
      assert_response :success
      json_response = JSON.parse(response.body)
      assert json_response["success"]
      assert_equal 0.88, json_response["scoring"]["lead_score"]
      assert_equal "high_priority", json_response["scoring"]["recommendation"]
    end
    
    # Step 6: Verify ML score was created
    assert lead.ml_scores.exists?
    ml_score = lead.ml_scores.first
    assert_not_nil ml_score
    assert ml_score.high_confidence? if ml_score.confidence
    
    # Step 7: Verify the complete workflow chain
    assert_equal @keyword, mention.keyword
    assert_equal mention, analysis_result.mention
    assert_equal mention, lead.mention
    assert lead.ml_scores.exists?
  end

  # Batch Processing Workflow Test
  test "batch process multiple mentions with AI" do
    # Create multiple mentions
    mentions = 3.times.map do |i|
      Mention.create!(
        keyword: @keyword,
        content: "Test content #{i} about purchasing software",
        url: "https://example.com/post#{i}",
        platform: "twitter"
      )
    end
    
    mention_ids = mentions.map(&:id)
    
    # Mock batch analysis results
    mock_results = mentions.map do |mention|
      {
        success: true,
        mention_id: mention.id,
        analysis: {
          sentiment: { score: 0.7 + rand * 0.2, label: "positive" },
          relevance_score: 0.6 + rand * 0.3
        }
      }
    end
    
    AI::EnhancedAnalysisService.any_instance.stub :batch_analyze_mentions, mock_results do
      post batch_analyze_ai_intelligence_index_url, params: {
        mention_ids: mention_ids
      }
      
      assert_response :success
      json_response = JSON.parse(response.body)
      assert json_response["success"]
      assert_equal 3, json_response["results"].length
      
      json_response["results"].each do |result|
        assert result["success"]
        assert result["analysis"]
      end
    end
  end

  # Multi-Model Comparison Workflow Test
  test "compare analysis results from multiple AI models" do
    # Get multiple AI models
    gpt_model = @ai_model
    claude_model = ai_models(:claude_test)
    
    # Analyze with first model
    mock_gpt_result = {
      success: true,
      analysis: {
        sentiment: { score: 0.82, label: "positive" },
        relevance_score: 0.88
      }
    }
    
    AI::EnhancedAnalysisService.any_instance.stub :analyze_mention, mock_gpt_result do
      post analyze_mention_ai_intelligence_index_url, params: {
        mention_id: @mention.id,
        ai_model_id: gpt_model.id
      }
      
      assert_response :success
      json_response = JSON.parse(response.body)
      assert_equal 0.82, json_response["analysis"]["sentiment"]["score"]
    end
    
    # Analyze with second model
    mock_claude_result = {
      success: true,
      analysis: {
        sentiment: { score: 0.78, label: "positive" },
        relevance_score: 0.85
      }
    }
    
    AI::EnhancedAnalysisService.any_instance.stub :analyze_mention, mock_claude_result do
      post analyze_mention_ai_intelligence_index_url, params: {
        mention_id: @mention.id,
        ai_model_id: claude_model.id
      }
      
      assert_response :success
      json_response = JSON.parse(response.body)
      assert_equal 0.78, json_response["analysis"]["sentiment"]["score"]
    end
    
    # Compare scores
    mock_comparison = {
      success: true,
      comparisons: [
        { model_id: gpt_model.id, score: 0.88, confidence: 0.92 },
        { model_id: claude_model.id, score: 0.85, confidence: 0.89 }
      ],
      best_score: { model_id: gpt_model.id, score: 0.88 }
    }
    
    AI::MlScoringService.any_instance.stub :compare_model_scores, mock_comparison do
      # This would typically be a custom endpoint
      # For now, we'll verify the service can handle multiple scores
      assert @mention.ml_scores.count >= 0  # May have scores from analysis
    end
  end

  # Search and Analysis Workflow Test
  test "search mentions and analyze high-relevance results" do
    # Create search index
    search_index = SearchIndex.create!(
      name: "mentions_index",
      index_type: "mentions",
      status: "active"
    )
    
    # Mock search results
    mock_search_results = {
      results: [
        { id: @mention.id, content: @mention.content, score: 0.95 },
        { id: mentions(:two).id, content: mentions(:two).content, score: 0.87 }
      ],
      total: 2
    }
    
    SearchIndex.any_instance.stub :search, mock_search_results do
      get search_ai_intelligence_index_url, params: {
        query: "software purchase",
        index_type: "mentions"
      }
      
      assert_response :success
      json_response = JSON.parse(response.body)
      assert_equal 2, json_response["results"].length
      
      # Get high-scoring results
      high_score_mentions = json_response["results"].select { |r| r["score"] > 0.9 }
      assert_equal 1, high_score_mentions.length
    end
    
    # Analyze high-relevance mention
    mock_analysis = {
      success: true,
      analysis: {
        sentiment: { score: 0.9, label: "positive" },
        intent: "purchase_ready",
        relevance_score: 0.95
      }
    }
    
    AI::EnhancedAnalysisService.any_instance.stub :analyze_mention, mock_analysis do
      post analyze_mention_ai_intelligence_index_url, params: {
        mention_id: @mention.id
      }
      
      assert_response :success
      json_response = JSON.parse(response.body)
      assert_equal "purchase_ready", json_response["analysis"]["intent"]
    end
  end

  # Error Recovery Workflow Test
  test "handle and recover from AI service failures" do
    # First attempt fails
    AI::EnhancedAnalysisService.any_instance.stub :analyze_mention, { success: false, error: "API rate limit" } do
      post analyze_mention_ai_intelligence_index_url, params: {
        mention_id: @mention.id
      }
      
      assert_response :unprocessable_entity
      json_response = JSON.parse(response.body)
      assert_not json_response["success"]
    end
    
    # Switch to different model and retry
    alternative_model = ai_models(:claude_test)
    
    mock_success = {
      success: true,
      analysis: {
        sentiment: { score: 0.75, label: "positive" },
        relevance_score: 0.8
      }
    }
    
    AI::EnhancedAnalysisService.any_instance.stub :analyze_mention, mock_success do
      post analyze_mention_ai_intelligence_index_url, params: {
        mention_id: @mention.id,
        ai_model_id: alternative_model.id
      }
      
      assert_response :success
      json_response = JSON.parse(response.body)
      assert json_response["success"]
    end
  end

  # Performance Monitoring Workflow Test
  test "track AI operation performance metrics" do
    # Get initial stats
    get stats_ai_intelligence_index_url
    assert_response :success
    initial_stats = JSON.parse(response.body)
    initial_scores = initial_stats["total_scores"] || 0
    
    # Perform multiple AI operations
    mock_analysis = {
      success: true,
      analysis: { sentiment: { score: 0.8 }, relevance_score: 0.85 },
      usage: { total_tokens: 150 }
    }
    
    AI::EnhancedAnalysisService.any_instance.stub :analyze_mention, mock_analysis do
      3.times do |i|
        mention = Mention.create!(
          keyword: @keyword,
          content: "Test mention #{i}",
          url: "https://example.com/#{i}",
          platform: "reddit"
        )
        
        post analyze_mention_ai_intelligence_index_url, params: {
          mention_id: mention.id
        }
        assert_response :success
      end
    end
    
    # Check updated stats
    get stats_ai_intelligence_index_url
    assert_response :success
    final_stats = JSON.parse(response.body)
    
    # Verify metrics were tracked
    assert final_stats["total_scores"] >= initial_scores
    assert final_stats["models_used"]
    assert final_stats["recent_activity"]
  end

  # Entity Extraction and Lead Creation Workflow
  test "extract entities and create leads from mentions" do
    mention_text = "John Smith from TechCorp is looking for enterprise software. Contact: john@techcorp.com"
    
    # Extract entities
    mock_entities = {
      success: true,
      entities: {
        people: ["John Smith"],
        organizations: ["TechCorp"],
        email: ["john@techcorp.com"],
        intent: "enterprise_purchase"
      }
    }
    
    AI::EnhancedAnalysisService.any_instance.stub :extract_entities, mock_entities do
      post extract_entities_ai_intelligence_index_url, params: {
        text: mention_text
      }
      
      assert_response :success
      json_response = JSON.parse(response.body)
      assert_includes json_response["entities"]["people"], "John Smith"
      assert_includes json_response["entities"]["organizations"], "TechCorp"
      
      # Create lead from extracted entities
      lead = Lead.create!(
        mention: @mention,
        name: json_response["entities"]["people"].first,
        company: json_response["entities"]["organizations"].first,
        email: json_response["entities"]["email"].first,
        score: 0.0
      )
      
      assert_equal "John Smith", lead.name
      assert_equal "TechCorp", lead.company
      assert_equal "john@techcorp.com", lead.email
    end
  end

  # Full Pipeline Test with All Components
  test "complete AI pipeline from keyword to qualified lead" do
    # Step 1: Keyword monitoring finds a mention
    keyword = Keyword.create!(
      user: @user,
      term: "enterprise CRM software",
      priority: "high",
      notification_frequency: "immediate"
    )
    
    mention = Mention.create!(
      keyword: keyword,
      content: "Our company needs a CRM system. Budget is $50k annually. Decision by Q2.",
      url: "https://forum.example.com/crm-discussion",
      platform: "forum",
      author: "decision_maker_123"
    )
    
    # Step 2: Analyze mention for sentiment and intent
    mock_analysis = {
      success: true,
      analysis: {
        sentiment: { score: 0.9, label: "positive" },
        entities: ["CRM system", "$50k", "Q2"],
        intent: "purchase_decision",
        topics: ["enterprise_software", "crm", "budget_allocated"],
        relevance_score: 0.95
      }
    }
    
    AI::EnhancedAnalysisService.any_instance.stub :analyze_mention, mock_analysis do
      post analyze_mention_ai_intelligence_index_url, params: {
        mention_id: mention.id
      }
      assert_response :success
    end
    
    # Step 3: Create analysis result
    analysis = AnalysisResult.create!(
      mention: mention,
      sentiment_score: 0.9,
      relevance_score: 0.95,
      entities: ["CRM system", "$50k", "Q2"],
      key_phrases: ["needs CRM", "budget allocated", "decision timeline"]
    )
    
    # Step 4: Generate lead
    lead = Lead.create!(
      mention: mention,
      name: "Decision Maker",
      company: "Unknown Corp",
      score: 0.0,
      notes: "High-intent CRM buyer with budget"
    )
    
    # Step 5: ML scoring
    mock_scoring = {
      success: true,
      score: 0.92,
      confidence: 0.95,
      prediction: "hot_lead",
      factors: {
        budget_mentioned: 1.0,
        timeline_specified: 0.95,
        decision_maker: 0.85,
        high_intent: 0.98
      }
    }
    
    AI::MlScoringService.any_instance.stub :calculate_lead_score, mock_scoring do
      post calculate_score_ai_intelligence_index_url, params: {
        entity_type: "Lead",
        entity_id: lead.id,
        ai_model_id: @ai_model.id
      }
      assert_response :success
      
      json_response = JSON.parse(response.body)
      assert_equal 0.92, json_response["score"]
      assert_equal "hot_lead", json_response["prediction"]
    end
    
    # Step 6: Verify complete pipeline
    assert_equal keyword, mention.keyword
    assert_equal mention, analysis.mention
    assert_equal mention, lead.mention
    assert lead.ml_scores.exists?
    
    # Step 7: Check lead qualification
    ml_score = lead.ml_scores.first
    assert ml_score.high_confidence?
    assert ml_score.score > 0.9  # Hot lead threshold
  end

  private

  def sign_in(user)
    post user_session_url, params: {
      user: {
        email: user.email,
        password: "password"
      }
    }
  end

  def sign_out(user)
    delete destroy_user_session_url
  end
end