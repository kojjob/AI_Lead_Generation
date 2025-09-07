require "test_helper"

class AI::EnhancedAnalysisServiceTest < ActiveSupport::TestCase
  def setup
    @service = AI::EnhancedAnalysisService.new
    @mention = mentions(:one)
    @lead = leads(:one)
    @analysis_result = analysis_results(:one)
    @ai_model = ai_models(:gpt_4_test)
  end

  # Initialization Tests
  test "should initialize with default AI model" do
    service = AI::EnhancedAnalysisService.new
    assert_not_nil service
  end

  test "should initialize with specific AI model" do
    service = AI::EnhancedAnalysisService.new(ai_model: @ai_model)
    assert_not_nil service
  end

  # Mention Analysis Tests
  test "should analyze mention successfully" do
    mock_ai_response = {
      content: JSON.generate({
        sentiment: { score: 0.8, label: "positive" },
        entities: [ "Company A", "Product B" ],
        intent: "purchase_inquiry",
        topics: [ "technology", "software" ],
        relevance_score: 0.9
      }),
      usage: { total_tokens: 100 }
    }

    AI::ModelAgnosticService.any_instance.stub :chat, mock_ai_response do
      result = @service.analyze_mention(@mention)

      assert result[:success]
      assert_not_nil result[:analysis]
      assert_equal 0.8, result[:analysis][:sentiment][:score]
      assert_equal "positive", result[:analysis][:sentiment][:label]
      assert_includes result[:analysis][:entities], "Company A"
      assert_equal "purchase_inquiry", result[:analysis][:intent]
      assert_equal 0.9, result[:analysis][:relevance_score]
    end
  end

  test "should handle mention analysis errors" do
    AI::ModelAgnosticService.any_instance.stub :chat, { error: "API Error" } do
      result = @service.analyze_mention(@mention)

      assert_not result[:success]
      assert result[:error]
      assert_match /API Error/, result[:error]
    end
  end

  test "should create ML score for mention analysis" do
    mock_ai_response = {
      content: JSON.generate({
        sentiment: { score: 0.8, label: "positive" },
        relevance_score: 0.85
      }),
      usage: { total_tokens: 100 }
    }

    AI::ModelAgnosticService.any_instance.stub :chat, mock_ai_response do
      assert_difference "MlScore.count", 1 do
        @service.analyze_mention(@mention)
      end

      ml_score = @mention.ml_scores.last
      assert_equal 0.85, ml_score.score
      assert_equal @ai_model, ml_score.ai_model
    end
  end

  # Lead Scoring Tests
  test "should score lead successfully" do
    mock_ai_response = {
      content: JSON.generate({
        lead_score: 0.92,
        confidence: 0.88,
        factors: {
          engagement: 0.9,
          intent: 0.95,
          budget: 0.85,
          timing: 0.8
        },
        recommendation: "high_priority"
      }),
      usage: { total_tokens: 150 }
    }

    AI::ModelAgnosticService.any_instance.stub :chat, mock_ai_response do
      result = @service.score_lead(@lead)

      assert result[:success]
      assert_not_nil result[:scoring]
      assert_equal 0.92, result[:scoring][:lead_score]
      assert_equal 0.88, result[:scoring][:confidence]
      assert_equal "high_priority", result[:scoring][:recommendation]
      assert_equal 0.9, result[:scoring][:factors][:engagement]
    end
  end

  test "should handle lead scoring errors" do
    AI::ModelAgnosticService.any_instance.stub :chat, { error: "API Error" } do
      result = @service.score_lead(@lead)

      assert_not result[:success]
      assert result[:error]
    end
  end

  test "should create ML score for lead" do
    mock_ai_response = {
      content: JSON.generate({
        lead_score: 0.75,
        confidence: 0.82
      }),
      usage: { total_tokens: 120 }
    }

    AI::ModelAgnosticService.any_instance.stub :chat, mock_ai_response do
      assert_difference "MlScore.count", 1 do
        @service.score_lead(@lead)
      end

      ml_score = @lead.ml_scores.last
      assert_equal 0.75, ml_score.score
      assert_equal 0.82, ml_score.confidence
    end
  end

  # Sentiment Analysis Tests
  test "should perform sentiment analysis" do
    text = "I absolutely love this product! It's amazing and works perfectly."

    mock_ai_response = {
      content: JSON.generate({
        sentiment: "positive",
        score: 0.95,
        confidence: 0.92,
        emotions: [ "joy", "satisfaction" ]
      }),
      usage: { total_tokens: 50 }
    }

    AI::ModelAgnosticService.any_instance.stub :chat, mock_ai_response do
      result = @service.analyze_sentiment(text)

      assert result[:success]
      assert_equal "positive", result[:sentiment][:sentiment]
      assert_equal 0.95, result[:sentiment][:score]
      assert_equal 0.92, result[:sentiment][:confidence]
      assert_includes result[:sentiment][:emotions], "joy"
    end
  end

  test "should handle negative sentiment" do
    text = "This is terrible. I'm very disappointed and frustrated."

    mock_ai_response = {
      content: JSON.generate({
        sentiment: "negative",
        score: 0.1,
        confidence: 0.89,
        emotions: [ "anger", "disappointment" ]
      }),
      usage: { total_tokens: 45 }
    }

    AI::ModelAgnosticService.any_instance.stub :chat, mock_ai_response do
      result = @service.analyze_sentiment(text)

      assert result[:success]
      assert_equal "negative", result[:sentiment][:sentiment]
      assert_equal 0.1, result[:sentiment][:score]
      assert_includes result[:sentiment][:emotions], "anger"
    end
  end

  test "should handle neutral sentiment" do
    text = "The product exists and functions as described."

    mock_ai_response = {
      content: JSON.generate({
        sentiment: "neutral",
        score: 0.5,
        confidence: 0.85,
        emotions: []
      }),
      usage: { total_tokens: 40 }
    }

    AI::ModelAgnosticService.any_instance.stub :chat, mock_ai_response do
      result = @service.analyze_sentiment(text)

      assert result[:success]
      assert_equal "neutral", result[:sentiment][:sentiment]
      assert_equal 0.5, result[:sentiment][:score]
    end
  end

  # Entity Extraction Tests
  test "should extract entities from text" do
    text = "John Smith from Apple Inc. met with Sarah Johnson from Microsoft in San Francisco."

    mock_ai_response = {
      content: JSON.generate({
        entities: {
          people: [ "John Smith", "Sarah Johnson" ],
          organizations: [ "Apple Inc.", "Microsoft" ],
          locations: [ "San Francisco" ],
          products: [],
          dates: [],
          money: []
        }
      }),
      usage: { total_tokens: 60 }
    }

    AI::ModelAgnosticService.any_instance.stub :chat, mock_ai_response do
      result = @service.extract_entities(text)

      assert result[:success]
      assert_includes result[:entities][:people], "John Smith"
      assert_includes result[:entities][:organizations], "Apple Inc."
      assert_includes result[:entities][:locations], "San Francisco"
    end
  end

  test "should handle empty entity extraction" do
    text = "This is just regular text without any special entities."

    mock_ai_response = {
      content: JSON.generate({
        entities: {
          people: [],
          organizations: [],
          locations: [],
          products: [],
          dates: [],
          money: []
        }
      }),
      usage: { total_tokens: 40 }
    }

    AI::ModelAgnosticService.any_instance.stub :chat, mock_ai_response do
      result = @service.extract_entities(text)

      assert result[:success]
      assert_empty result[:entities][:people]
      assert_empty result[:entities][:organizations]
    end
  end

  # Intent Detection Tests
  test "should detect purchase intent" do
    text = "I'm interested in buying your product. What's the price and how can I order?"

    mock_ai_response = {
      content: JSON.generate({
        intent: "purchase_inquiry",
        confidence: 0.92,
        sub_intents: [ "pricing_question", "ordering_process" ]
      }),
      usage: { total_tokens: 55 }
    }

    AI::ModelAgnosticService.any_instance.stub :chat, mock_ai_response do
      result = @service.detect_intent(text)

      assert result[:success]
      assert_equal "purchase_inquiry", result[:intent][:intent]
      assert_equal 0.92, result[:intent][:confidence]
      assert_includes result[:intent][:sub_intents], "pricing_question"
    end
  end

  test "should detect support intent" do
    text = "I'm having trouble with the software. It keeps crashing. Can you help?"

    mock_ai_response = {
      content: JSON.generate({
        intent: "support_request",
        confidence: 0.88,
        sub_intents: [ "bug_report", "help_request" ]
      }),
      usage: { total_tokens: 50 }
    }

    AI::ModelAgnosticService.any_instance.stub :chat, mock_ai_response do
      result = @service.detect_intent(text)

      assert result[:success]
      assert_equal "support_request", result[:intent][:intent]
      assert_includes result[:intent][:sub_intents], "bug_report"
    end
  end

  # Topic Modeling Tests
  test "should extract topics from text" do
    text = "The latest developments in artificial intelligence and machine learning..."

    mock_ai_response = {
      content: JSON.generate({
        topics: [ "artificial_intelligence", "machine_learning", "technology" ],
        weights: [ 0.4, 0.35, 0.25 ]
      }),
      usage: { total_tokens: 45 }
    }

    AI::ModelAgnosticService.any_instance.stub :chat, mock_ai_response do
      result = @service.extract_topics(text)

      assert result[:success]
      assert_includes result[:topics][:topics], "artificial_intelligence"
      assert_equal 0.4, result[:topics][:weights][0]
    end
  end

  # Batch Processing Tests
  test "should analyze multiple mentions in batch" do
    mentions = [ @mention, mentions(:two) ]

    mock_ai_response = {
      content: JSON.generate({
        sentiment: { score: 0.7, label: "positive" },
        relevance_score: 0.8
      }),
      usage: { total_tokens: 80 }
    }

    AI::ModelAgnosticService.any_instance.stub :chat, mock_ai_response do
      results = @service.batch_analyze_mentions(mentions)

      assert_kind_of Array, results
      assert_equal 2, results.length
      results.each do |result|
        assert result[:success]
        assert result[:analysis]
      end
    end
  end

  test "should handle partial batch failures" do
    mentions = [ @mention, mentions(:two) ]
    call_count = 0

    mock_proc = lambda do |_|
      call_count += 1
      if call_count == 1
        { content: JSON.generate({ sentiment: { score: 0.7 } }), usage: { total_tokens: 50 } }
      else
        { error: "API Error" }
      end
    end

    AI::ModelAgnosticService.any_instance.stub :chat, mock_proc do
      results = @service.batch_analyze_mentions(mentions)

      assert_equal 2, results.length
      assert results[0][:success]
      assert_not results[1][:success]
    end
  end

  # Keyword Extraction Tests
  test "should extract keywords from text" do
    text = "Cloud computing revolutionizes data storage and processing capabilities."

    mock_ai_response = {
      content: JSON.generate({
        keywords: [ "cloud computing", "data storage", "processing", "revolutionizes" ],
        relevance_scores: [ 0.95, 0.85, 0.8, 0.7 ]
      }),
      usage: { total_tokens: 40 }
    }

    AI::ModelAgnosticService.any_instance.stub :chat, mock_ai_response do
      result = @service.extract_keywords(text)

      assert result[:success]
      assert_includes result[:keywords][:keywords], "cloud computing"
      assert_equal 0.95, result[:keywords][:relevance_scores][0]
    end
  end

  # Summary Generation Tests
  test "should generate summary of text" do
    text = "Long article about technology..." * 10

    mock_ai_response = {
      content: JSON.generate({
        summary: "A comprehensive overview of technology trends.",
        key_points: [ "Innovation", "Digital transformation", "Future outlook" ]
      }),
      usage: { total_tokens: 200 }
    }

    AI::ModelAgnosticService.any_instance.stub :chat, mock_ai_response do
      result = @service.summarize_text(text)

      assert result[:success]
      assert result[:summary][:summary]
      assert_includes result[:summary][:key_points], "Innovation"
    end
  end

  # Comparative Analysis Tests
  test "should compare multiple texts" do
    texts = [ "Text about AI", "Text about ML", "Text about deep learning" ]

    mock_ai_response = {
      content: JSON.generate({
        similarities: [ "All discuss machine intelligence", "Focus on algorithms" ],
        differences: [ "AI is broader", "ML is subset", "DL is specialized" ],
        relationships: "hierarchical"
      }),
      usage: { total_tokens: 150 }
    }

    AI::ModelAgnosticService.any_instance.stub :chat, mock_ai_response do
      result = @service.compare_texts(texts)

      assert result[:success]
      assert result[:comparison][:similarities]
      assert result[:comparison][:differences]
      assert_equal "hierarchical", result[:comparison][:relationships]
    end
  end

  # Error Handling Tests
  test "should handle invalid JSON response" do
    mock_ai_response = {
      content: "Invalid JSON {not valid}",
      usage: { total_tokens: 30 }
    }

    AI::ModelAgnosticService.any_instance.stub :chat, mock_ai_response do
      result = @service.analyze_sentiment("test text")

      assert_not result[:success]
      assert result[:error]
      assert_match /parsing/, result[:error].downcase
    end
  end

  test "should handle network timeouts" do
    AI::ModelAgnosticService.any_instance.stub :chat, ->(_) { raise Net::ReadTimeout } do
      result = @service.analyze_sentiment("test text")

      assert_not result[:success]
      assert result[:error]
    end
  end

  test "should handle rate limits" do
    AI::ModelAgnosticService.any_instance.stub :chat, { error: "Rate limit exceeded" } do
      result = @service.analyze_sentiment("test text")

      assert_not result[:success]
      assert_match /Rate limit/, result[:error]
    end
  end

  # Configuration Tests
  test "should use custom AI model configuration" do
    @ai_model.temperature = 0.3
    @ai_model.max_tokens = 2000
    @ai_model.save!

    service = AI::EnhancedAnalysisService.new(ai_model: @ai_model)
    assert_not_nil service
  end

  test "should fall back to default model when not specified" do
    service = AI::EnhancedAnalysisService.new
    assert_not_nil service
  end
end
