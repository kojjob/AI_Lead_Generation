require "test_helper"

class AiModelTest < ActiveSupport::TestCase
  def setup
    @ai_model = ai_models(:gpt_4_test)
  end

  # Validation Tests
  test "should be valid with valid attributes" do
    assert @ai_model.valid?
  end

  test "should require name" do
    @ai_model.name = nil
    assert_not @ai_model.valid?
    assert_includes @ai_model.errors[:name], "can't be blank"
  end

  test "should require unique name" do
    duplicate_model = @ai_model.dup
    @ai_model.save
    assert_not duplicate_model.valid?
    assert_includes duplicate_model.errors[:name], "has already been taken"
  end

  test "should require provider" do
    @ai_model.provider = nil
    assert_not @ai_model.valid?
    assert_includes @ai_model.errors[:provider], "can't be blank"
  end

  test "should validate provider is included in list" do
    @ai_model.provider = "invalid_provider"
    assert_not @ai_model.valid?
    assert_includes @ai_model.errors[:provider], "is not included in the list"
  end

  test "should accept valid providers" do
    %w[openai anthropic google_gemini cohere ollama huggingface replicate].each do |provider|
      @ai_model.provider = provider
      assert @ai_model.valid?, "#{provider} should be valid"
    end
  end


  test "should require model_name" do
    @ai_model.model_name = nil
    assert_not @ai_model.valid?
    assert_includes @ai_model.errors[:model_name], "can't be blank"
  end

  test "should validate temperature between 0 and 2" do
    @ai_model.temperature = -0.1
    assert_not @ai_model.valid?
    assert_includes @ai_model.errors[:temperature], "must be greater than or equal to 0"

    @ai_model.temperature = 2.1
    assert_not @ai_model.valid?
    assert_includes @ai_model.errors[:temperature], "must be less than or equal to 2"

    @ai_model.temperature = 0.7
    assert @ai_model.valid?
  end

  test "should validate max_tokens is positive" do
    @ai_model.max_tokens = -1
    assert_not @ai_model.valid?
    assert_includes @ai_model.errors[:max_tokens], "must be greater than 0"

    @ai_model.max_tokens = 1000
    assert @ai_model.valid?
  end

  # Association Tests
  test "should have many ml_scores" do
    assert_respond_to @ai_model, :ml_scores
  end

  test "should destroy associated ml_scores when destroyed" do
    @ai_model.save!
    ml_score = @ai_model.ml_scores.create!(
      scoreable: mentions(:one),
      score: 0.85,
      confidence: 0.9
    )

    assert_difference "MlScore.count", -1 do
      @ai_model.destroy
    end
  end

  # Scope Tests
  test "active scope should return only active models" do
    active_models = AiModel.active
    active_models.each do |model|
      assert model.active?
    end
  end

  test "by_provider scope should filter by provider" do
    openai_models = AiModel.by_provider("openai")
    openai_models.each do |model|
      assert_equal "openai", model.provider
    end
  end

  # Method Tests
  test "should return correct display name" do
    assert_equal "GPT-4 Test (openai)", @ai_model.display_name
  end

  test "should check if model supports streaming" do
    @ai_model.supports_streaming = true
    assert @ai_model.supports_streaming?

    @ai_model.supports_streaming = false
    assert_not @ai_model.supports_streaming?
  end

  test "should check if model supports function calling" do
    @ai_model.supports_functions = true
    assert @ai_model.supports_functions?

    @ai_model.supports_functions = false
    assert_not @ai_model.supports_functions?
  end

  test "should return configuration as hash" do
    config = @ai_model.configuration

    assert_kind_of Hash, config
    assert_equal @ai_model.provider, config[:provider]
    assert_equal @ai_model.model_name, config[:model_name]
    assert_equal @ai_model.temperature, config[:temperature]
    assert_equal @ai_model.max_tokens, config[:max_tokens]
  end

  test "should merge settings correctly" do
    @ai_model.settings = { custom_option: "value", api_base: "https://custom.api" }
    config = @ai_model.configuration

    assert_equal "value", config[:custom_option]
    assert_equal "https://custom.api", config[:api_base]
  end

  # Default Values Tests
  test "should set default temperature to 0.7" do
    new_model = AiModel.new(
      name: "Test Model",
      provider: "openai",
      model_name: "gpt-3.5-turbo"
    )
    assert_equal 0.7, new_model.temperature
  end

  test "should set default max_tokens to 1000" do
    new_model = AiModel.new(
      name: "Test Model",
      provider: "openai",
      model_name: "gpt-3.5-turbo"
    )
    assert_equal 1000, new_model.max_tokens
  end

  test "should set active to true by default" do
    new_model = AiModel.new(
      name: "Test Model",
      provider: "openai",
      model_name: "gpt-3.5-turbo"
    )
    assert new_model.active?
  end

  test "should initialize settings as empty hash" do
    new_model = AiModel.new(
      name: "Test Model",
      provider: "openai",
      model_name: "gpt-3.5-turbo"
    )
    assert_equal({}, new_model.settings)
  end
end
