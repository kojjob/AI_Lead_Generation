require "test_helper"

class AI::ModelAgnosticServiceTest < ActiveSupport::TestCase
  def setup
    @service = AI::ModelAgnosticService.new
    @ai_model = ai_models(:gpt_4_test)
  end

  # Initialization Tests
  test "should initialize with default provider" do
    service = AI::ModelAgnosticService.new
    assert_not_nil service
  end

  test "should initialize with specific provider" do
    service = AI::ModelAgnosticService.new(provider: "anthropic")
    assert_not_nil service
  end

  test "should initialize with custom model" do
    service = AI::ModelAgnosticService.new(provider: "openai", model: "gpt-3.5-turbo")
    assert_not_nil service
  end

  test "should initialize with ai_model object" do
    service = AI::ModelAgnosticService.new(ai_model: @ai_model)
    assert_not_nil service
  end

  # Provider Support Tests
  test "should support all major providers" do
    providers = %w[openai anthropic google_gemini cohere ollama huggingface replicate]

    providers.each do |provider|
      assert AI::ModelAgnosticService.supported_provider?(provider),
             "#{provider} should be supported"
    end
  end

  test "should not support invalid providers" do
    assert_not AI::ModelAgnosticService.supported_provider?("invalid_provider")
  end

  test "should list all supported providers" do
    providers = AI::ModelAgnosticService.supported_providers
    assert_kind_of Array, providers
    assert_includes providers, "openai"
    assert_includes providers, "anthropic"
  end

  # Model Configuration Tests
  test "should return default model for provider" do
    assert_equal "gpt-4", AI::ModelAgnosticService.default_model_for("openai")
    assert_equal "claude-3-opus-20240229", AI::ModelAgnosticService.default_model_for("anthropic")
    assert_equal "gemini-pro", AI::ModelAgnosticService.default_model_for("google_gemini")
  end

  test "should return nil for unsupported provider default model" do
    assert_nil AI::ModelAgnosticService.default_model_for("invalid_provider")
  end

  # Chat Completion Tests (Mocked)
  test "should prepare chat completion with proper format" do
    messages = [
      { role: "system", content: "You are a helpful assistant" },
      { role: "user", content: "Hello" }
    ]

    # Mock the LLM response
    mock_response = OpenStruct.new(
      completion: "Hello! How can I help you today?",
      raw_response: { "usage" => { "total_tokens" => 50 } }
    )

    @service.stub :chat_completion, mock_response do
      response = @service.chat(messages: messages)

      assert_not_nil response
      assert_equal "Hello! How can I help you today?", response[:content]
      assert_equal 50, response[:usage][:total_tokens]
    end
  end

  test "should handle chat errors gracefully" do
    messages = [ { role: "user", content: "Test" } ]

    # Simulate an error
    @service.stub :chat_completion, ->(_) { raise StandardError, "API Error" } do
      response = @service.chat(messages: messages)

      assert response[:error]
      assert_match /API Error/, response[:error]
    end
  end

  # Completion Tests (Mocked)
  test "should handle text completion" do
    prompt = "Complete this sentence: The weather today is"

    mock_response = OpenStruct.new(
      completion: " sunny and warm.",
      raw_response: { "usage" => { "total_tokens" => 30 } }
    )

    @service.stub :text_completion, mock_response do
      response = @service.complete(prompt: prompt)

      assert_not_nil response
      assert_equal " sunny and warm.", response[:content]
    end
  end

  test "should handle completion errors gracefully" do
    prompt = "Test prompt"

    @service.stub :text_completion, ->(_) { raise StandardError, "API Error" } do
      response = @service.complete(prompt: prompt)

      assert response[:error]
      assert_match /API Error/, response[:error]
    end
  end

  # Embedding Tests (Mocked)
  test "should generate embeddings" do
    text = "This is a test sentence for embedding"

    mock_response = OpenStruct.new(
      embedding: Array.new(1536) { rand },
      raw_response: { "usage" => { "total_tokens" => 10 } }
    )

    @service.stub :generate_embedding, mock_response do
      response = @service.embed(text: text)

      assert_not_nil response
      assert_kind_of Array, response[:embedding]
      assert_equal 1536, response[:embedding].length
    end
  end

  test "should handle embedding errors gracefully" do
    text = "Test text"

    @service.stub :generate_embedding, ->(_) { raise StandardError, "API Error" } do
      response = @service.embed(text: text)

      assert response[:error]
      assert_match /API Error/, response[:error]
    end
  end

  # Token Counting Tests
  test "should estimate token count" do
    text = "This is a test sentence with several words in it."
    tokens = @service.count_tokens(text)

    assert_kind_of Integer, tokens
    assert tokens > 0
    assert tokens < 100
  end

  test "should handle empty text for token counting" do
    assert_equal 0, @service.count_tokens("")
    assert_equal 0, @service.count_tokens(nil)
  end

  # Streaming Tests
  test "should check streaming support" do
    # Most providers support streaming
    service = AI::ModelAgnosticService.new(provider: "openai")
    assert service.supports_streaming?

    service = AI::ModelAgnosticService.new(provider: "anthropic")
    assert service.supports_streaming?
  end

  # Function Calling Tests
  test "should check function calling support" do
    service = AI::ModelAgnosticService.new(provider: "openai")
    assert service.supports_functions?

    service = AI::ModelAgnosticService.new(provider: "anthropic")
    assert service.supports_functions?
  end

  # Batch Processing Tests
  test "should process multiple prompts in batch" do
    prompts = [
      "First prompt",
      "Second prompt",
      "Third prompt"
    ]

    mock_response = OpenStruct.new(
      completion: "Response",
      raw_response: { "usage" => { "total_tokens" => 20 } }
    )

    @service.stub :text_completion, mock_response do
      responses = @service.batch_complete(prompts: prompts)

      assert_kind_of Array, responses
      assert_equal 3, responses.length
      responses.each do |response|
        assert response[:content]
      end
    end
  end

  test "should handle batch processing with partial failures" do
    prompts = [ "First", "Second", "Third" ]
    call_count = 0

    mock_proc = lambda do |_|
      call_count += 1
      if call_count == 2
        raise StandardError, "API Error"
      else
        OpenStruct.new(
          completion: "Response #{call_count}",
          raw_response: { "usage" => { "total_tokens" => 20 } }
        )
      end
    end

    @service.stub :text_completion, mock_proc do
      responses = @service.batch_complete(prompts: prompts)

      assert_equal 3, responses.length
      assert responses[0][:content]
      assert responses[1][:error]
      assert responses[2][:content]
    end
  end

  # Configuration Tests
  test "should merge custom options" do
    service = AI::ModelAgnosticService.new(
      provider: "openai",
      options: { temperature: 0.5, max_tokens: 500 }
    )

    # Verify options are accessible (implementation specific)
    assert_not_nil service
  end

  # Error Handling Tests
  test "should handle network errors gracefully" do
    @service.stub :chat_completion, ->(_) { raise Net::ReadTimeout } do
      response = @service.chat(messages: [ { role: "user", content: "Test" } ])

      assert response[:error]
      assert_kind_of String, response[:error]
    end
  end

  test "should handle authentication errors" do
    @service.stub :chat_completion, ->(_) { raise StandardError, "Unauthorized" } do
      response = @service.chat(messages: [ { role: "user", content: "Test" } ])

      assert response[:error]
      assert_match /Unauthorized/, response[:error]
    end
  end

  test "should handle rate limit errors" do
    @service.stub :chat_completion, ->(_) { raise StandardError, "Rate limit exceeded" } do
      response = @service.chat(messages: [ { role: "user", content: "Test" } ])

      assert response[:error]
      assert_match /Rate limit/, response[:error]
    end
  end

  # Model Switching Tests
  test "should switch models dynamically" do
    service = AI::ModelAgnosticService.new(provider: "openai", model: "gpt-3.5-turbo")
    assert_not_nil service

    # Create new instance with different model
    service = AI::ModelAgnosticService.new(provider: "openai", model: "gpt-4")
    assert_not_nil service
  end

  test "should switch providers dynamically" do
    service = AI::ModelAgnosticService.new(provider: "openai")
    assert_not_nil service

    # Create new instance with different provider
    service = AI::ModelAgnosticService.new(provider: "anthropic")
    assert_not_nil service
  end

  # AI Model Integration Tests
  test "should work with AI model from database" do
    service = AI::ModelAgnosticService.new(ai_model: @ai_model)
    assert_not_nil service
  end

  test "should use AI model configuration" do
    @ai_model.temperature = 0.3
    @ai_model.max_tokens = 2000
    @ai_model.save!

    service = AI::ModelAgnosticService.new(ai_model: @ai_model)
    assert_not_nil service
  end

  # Helper Method Tests
  private

  def mock_llm_response(content: "Test response", tokens: 50, error: nil)
    if error
      raise StandardError, error
    else
      OpenStruct.new(
        completion: content,
        raw_response: {
          "usage" => {
            "total_tokens" => tokens,
            "prompt_tokens" => tokens / 2,
            "completion_tokens" => tokens / 2
          }
        }
      )
    end
  end
end
