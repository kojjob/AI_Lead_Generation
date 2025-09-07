class SentimentAnalysisService
  include HTTParty
  
  # Configuration for different sentiment analysis providers
  PROVIDERS = {
    openai: {
      base_uri: 'https://api.openai.com/v1',
      model: 'gpt-3.5-turbo',
      max_tokens: 100
    },
    huggingface: {
      base_uri: 'https://api-inference.huggingface.co/models',
      model: 'cardiffnlp/twitter-roberta-base-sentiment-latest'
    },
    local: {
      # For local/offline sentiment analysis
      model: 'vader'
    }
  }.freeze

  def initialize(provider: :local)
    @provider = provider
    @config = PROVIDERS[provider]
    setup_provider
  end

  def analyze(text)
    return default_result if text.blank?

    case @provider
    when :openai
      analyze_with_openai(text)
    when :huggingface
      analyze_with_huggingface(text)
    when :local
      analyze_with_vader(text)
    else
      default_result
    end
  rescue StandardError => e
    Rails.logger.error "Sentiment analysis failed: #{e.message}"
    default_result.merge(error: e.message)
  end

  def analyze_batch(texts)
    texts.map { |text| analyze(text) }
  end

  private

  def setup_provider
    case @provider
    when :openai
      self.class.headers 'Authorization' => "Bearer #{Rails.application.credentials.openai_api_key}"
      self.class.headers 'Content-Type' => 'application/json'
    when :huggingface
      self.class.headers 'Authorization' => "Bearer #{Rails.application.credentials.huggingface_api_key}"
      self.class.headers 'Content-Type' => 'application/json'
    end
  end

  def analyze_with_openai(text)
    prompt = build_openai_prompt(text)
    
    response = self.class.post("#{@config[:base_uri]}/chat/completions", {
      body: {
        model: @config[:model],
        messages: [{ role: 'user', content: prompt }],
        max_tokens: @config[:max_tokens],
        temperature: 0.1
      }.to_json
    })

    if response.success?
      parse_openai_response(response.parsed_response)
    else
      default_result.merge(error: "OpenAI API error: #{response.code}")
    end
  end

  def analyze_with_huggingface(text)
    response = self.class.post("#{@config[:base_uri]}/#{@config[:model]}", {
      body: { inputs: text }.to_json
    })

    if response.success?
      parse_huggingface_response(response.parsed_response)
    else
      default_result.merge(error: "HuggingFace API error: #{response.code}")
    end
  end

  def analyze_with_vader(text)
    # Simple rule-based sentiment analysis for local processing
    # This is a basic implementation - in production, you might use a gem like 'vader_sentiment_ruby'
    
    positive_words = %w[good great excellent amazing wonderful fantastic love like enjoy happy excited positive]
    negative_words = %w[bad terrible awful horrible hate dislike angry sad disappointed negative]
    
    words = text.downcase.split(/\W+/)
    
    positive_count = words.count { |word| positive_words.include?(word) }
    negative_count = words.count { |word| negative_words.include?(word) }
    
    total_sentiment_words = positive_count + negative_count
    
    if total_sentiment_words == 0
      sentiment = 'neutral'
      score = 0.0
      confidence = 0.5
    elsif positive_count > negative_count
      sentiment = 'positive'
      score = (positive_count - negative_count).to_f / words.length
      confidence = [0.6 + (score * 0.4), 1.0].min
    elsif negative_count > positive_count
      sentiment = 'negative'
      score = (negative_count - positive_count).to_f / words.length * -1
      confidence = [0.6 + (score.abs * 0.4), 1.0].min
    else
      sentiment = 'neutral'
      score = 0.0
      confidence = 0.5
    end

    {
      sentiment: sentiment,
      score: score.round(3),
      confidence: confidence.round(3),
      provider: 'local_vader',
      details: {
        positive_words_found: positive_count,
        negative_words_found: negative_count,
        total_words: words.length
      }
    }
  end

  def build_openai_prompt(text)
    <<~PROMPT
      Analyze the sentiment of the following text and respond with a JSON object containing:
      - sentiment: "positive", "negative", or "neutral"
      - score: a number between -1 (very negative) and 1 (very positive)
      - confidence: a number between 0 and 1 indicating confidence in the analysis
      
      Text to analyze: "#{text}"
      
      Respond only with valid JSON, no additional text.
    PROMPT
  end

  def parse_openai_response(response)
    content = response.dig('choices', 0, 'message', 'content')
    parsed = JSON.parse(content)
    
    {
      sentiment: parsed['sentiment'],
      score: parsed['score'].to_f,
      confidence: parsed['confidence'].to_f,
      provider: 'openai',
      details: {
        model: @config[:model],
        usage: response['usage']
      }
    }
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse OpenAI response: #{e.message}"
    default_result.merge(error: "Invalid JSON response from OpenAI")
  end

  def parse_huggingface_response(response)
    # HuggingFace returns an array of label/score pairs
    results = response.first if response.is_a?(Array)
    
    if results && results.is_a?(Array)
      # Find the highest scoring sentiment
      best_result = results.max_by { |r| r['score'] }
      
      sentiment = map_huggingface_label(best_result['label'])
      score = calculate_sentiment_score(results)
      confidence = best_result['score']
      
      {
        sentiment: sentiment,
        score: score,
        confidence: confidence.round(3),
        provider: 'huggingface',
        details: {
          model: @config[:model],
          all_scores: results
        }
      }
    else
      default_result.merge(error: "Unexpected HuggingFace response format")
    end
  end

  def map_huggingface_label(label)
    case label.downcase
    when /positive/
      'positive'
    when /negative/
      'negative'
    else
      'neutral'
    end
  end

  def calculate_sentiment_score(results)
    # Convert HuggingFace scores to a -1 to 1 scale
    positive_score = results.find { |r| r['label'].downcase.include?('positive') }&.dig('score') || 0
    negative_score = results.find { |r| r['label'].downcase.include?('negative') }&.dig('score') || 0
    
    (positive_score - negative_score).round(3)
  end

  def default_result
    {
      sentiment: 'neutral',
      score: 0.0,
      confidence: 0.0,
      provider: @provider.to_s,
      details: {}
    }
  end

  # Class methods for convenience
  def self.analyze(text, provider: :local)
    new(provider: provider).analyze(text)
  end

  def self.analyze_batch(texts, provider: :local)
    new(provider: provider).analyze_batch(texts)
  end

  # Sentiment classification helpers
  def self.classify_sentiment(score)
    case score
    when 0.1..1.0
      'positive'
    when -1.0..-0.1
      'negative'
    else
      'neutral'
    end
  end

  def self.sentiment_emoji(sentiment)
    case sentiment.to_s.downcase
    when 'positive'
      '😊'
    when 'negative'
      '😞'
    else
      '😐'
    end
  end

  def self.sentiment_color(sentiment)
    case sentiment.to_s.downcase
    when 'positive'
      'green'
    when 'negative'
      'red'
    else
      'gray'
    end
  end
end
