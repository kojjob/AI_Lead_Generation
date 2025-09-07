module Ai
  class ModelAgnosticService
    attr_reader :provider, :model_name, :options

    SUPPORTED_PROVIDERS = %w[openai anthropic google_gemini cohere ollama].freeze

    def initialize(provider: nil, model: nil, options: {})
      @provider = provider || default_provider
      @model_name = model || default_model_for(provider)
      @options = options
      @llm = initialize_llm
    end

    def complete(prompt, **params)
      response = @llm.complete(prompt: prompt, **params)
      format_response(response)
    rescue => e
      handle_error(e)
    end

    def chat(messages, **params)
      response = @llm.chat(messages: messages, **params)
      format_response(response)
    rescue => e
      handle_error(e)
    end

    def embed(text, **params)
      response = @llm.embed(text: text, **params)
      format_embedding_response(response)
    rescue => e
      handle_error(e)
    end

    def analyze_content(content, analysis_type)
      prompt = build_analysis_prompt(content, analysis_type)
      
      messages = [
        { role: "system", content: system_prompt_for(analysis_type) },
        { role: "user", content: prompt }
      ]

      response = chat(messages, 
        temperature: 0.3,
        max_tokens: 2000
      )

      parse_analysis_response(response, analysis_type)
    end

    def score_lead(lead_data)
      prompt = build_lead_scoring_prompt(lead_data)
      
      messages = [
        { role: "system", content: lead_scoring_system_prompt },
        { role: "user", content: prompt }
      ]

      response = chat(messages,
        temperature: 0.2,
        max_tokens: 1000
      )

      parse_scoring_response(response)
    end

    def extract_entities(text)
      prompt = "Extract all entities (people, companies, emails, phones, locations) from the following text:\n\n#{text}"
      
      messages = [
        { role: "system", content: "You are an entity extraction specialist. Extract and categorize all entities found in the text. Return as JSON." },
        { role: "user", content: prompt }
      ]

      response = chat(messages,
        temperature: 0.1,
        max_tokens: 1500
      )

      parse_entity_response(response)
    end

    def summarize(text, max_length: 200)
      prompt = "Summarize the following text in #{max_length} characters or less:\n\n#{text}"
      
      messages = [
        { role: "system", content: "You are a concise summarization expert. Create clear, informative summaries." },
        { role: "user", content: prompt }
      ]

      response = chat(messages,
        temperature: 0.3,
        max_tokens: max_length * 2
      )

      response[:content].to_s.truncate(max_length)
    end

    def self.available_providers
      SUPPORTED_PROVIDERS.select { |p| provider_configured?(p) }
    end

    def self.provider_configured?(provider)
      case provider
      when 'openai'
        ENV['OPENAI_API_KEY'].present?
      when 'anthropic'
        ENV['ANTHROPIC_API_KEY'].present?
      when 'google_gemini'
        ENV['GOOGLE_GEMINI_API_KEY'].present?
      when 'cohere'
        ENV['COHERE_API_KEY'].present?
      when 'ollama'
        ENV['OLLAMA_URL'].present?
      else
        false
      end
    end

    private

    def initialize_llm
      case provider
      when 'openai'
        initialize_openai_llm
      when 'anthropic'
        initialize_anthropic_llm
      when 'google_gemini'
        initialize_gemini_llm
      when 'cohere'
        initialize_cohere_llm
      when 'ollama'
        initialize_ollama_llm
      else
        raise "Unsupported provider: #{provider}"
      end
    end

    def initialize_openai_llm
      require 'langchain/llm/openai'
      
      Langchain::LLM::OpenAI.new(
        api_key: ENV['OPENAI_API_KEY'],
        llm_options: {
          model: model_name,
          temperature: options[:temperature] || 0.3,
          max_tokens: options[:max_tokens] || 2000,
          **options.except(:temperature, :max_tokens)
        }
      )
    end

    def initialize_anthropic_llm
      require 'langchain/llm/anthropic'
      
      Langchain::LLM::Anthropic.new(
        api_key: ENV['ANTHROPIC_API_KEY'],
        llm_options: {
          model: model_name,
          temperature: options[:temperature] || 0.3,
          max_tokens: options[:max_tokens] || 2000,
          **options.except(:temperature, :max_tokens)
        }
      )
    end

    def initialize_gemini_llm
      require 'langchain/llm/google_gemini'
      
      Langchain::LLM::GoogleGemini.new(
        api_key: ENV['GOOGLE_GEMINI_API_KEY'],
        default_options: {
          model: model_name,
          temperature: options[:temperature] || 0.3,
          **options.except(:temperature)
        }
      )
    end

    def initialize_cohere_llm
      require 'langchain/llm/cohere'
      
      Langchain::LLM::Cohere.new(
        api_key: ENV['COHERE_API_KEY'],
        default_options: {
          model: model_name,
          temperature: options[:temperature] || 0.3,
          **options.except(:temperature)
        }
      )
    end

    def initialize_ollama_llm
      require 'langchain/llm/ollama'
      
      Langchain::LLM::Ollama.new(
        url: ENV['OLLAMA_URL'] || 'http://localhost:11434',
        default_options: {
          model: model_name,
          temperature: options[:temperature] || 0.3,
          **options.except(:temperature)
        }
      )
    end

    def default_provider
      # Return first configured provider
      self.class.available_providers.first || 'openai'
    end

    def default_model_for(provider)
      case provider
      when 'openai'
        'gpt-4-turbo-preview'
      when 'anthropic'
        'claude-3-opus-20240229'
      when 'google_gemini'
        'gemini-pro'
      when 'cohere'
        'command'
      when 'ollama'
        'llama2'
      else
        'gpt-3.5-turbo'
      end
    end

    def format_response(response)
      {
        content: response.completion || response.chat_completion,
        model: response.model || model_name,
        provider: provider,
        usage: response.usage,
        raw_response: response.raw_response
      }
    end

    def format_embedding_response(response)
      {
        embedding: response.embedding,
        model: response.model || model_name,
        provider: provider,
        usage: response.usage
      }
    end

    def handle_error(error)
      Rails.logger.error "AI Service Error (#{provider}): #{error.message}"
      
      {
        error: true,
        message: error.message,
        provider: provider,
        model: model_name
      }
    end

    def system_prompt_for(analysis_type)
      case analysis_type
      when :sentiment
        "You are a sentiment analysis expert. Analyze emotional tone and sentiment. Return JSON with sentiment (positive/negative/neutral/mixed) and confidence score."
      when :entities
        "You are an entity extraction specialist. Identify all entities. Return JSON with categorized entities."
      when :intent
        "You are an intent detection expert. Identify primary intent and urgency. Return JSON with intent classification."
      when :relevance
        "You are a relevance scoring expert. Assess content relevance. Return JSON with relevance score and factors."
      when :quality
        "You are a content quality assessor. Evaluate content quality. Return JSON with quality score and assessment."
      else
        "You are an AI assistant. Provide comprehensive analysis in JSON format."
      end
    end

    def lead_scoring_system_prompt
      <<~PROMPT
        You are a lead scoring expert. Analyze lead data and provide:
        1. Score (0-1): Overall lead quality
        2. Confidence (0-1): Confidence in assessment
        3. Factors: Key scoring factors
        4. Recommendations: Next steps
        
        Return as JSON with keys: score, confidence, factors, recommendations
      PROMPT
    end

    def build_analysis_prompt(content, analysis_type)
      <<~PROMPT
        Analyze the following content for #{analysis_type}:
        
        #{content}
        
        Provide detailed analysis in JSON format.
      PROMPT
    end

    def build_lead_scoring_prompt(lead_data)
      <<~PROMPT
        Score the following lead:
        
        #{lead_data.to_json}
        
        Consider all factors and provide comprehensive scoring.
      PROMPT
    end

    def parse_analysis_response(response, analysis_type)
      return response if response[:error]
      
      begin
        content = response[:content].to_s
        
        # Try to extract JSON from the response
        json_match = content.match(/\{.*\}/m)
        if json_match
          JSON.parse(json_match[0]).symbolize_keys
        else
          # Fallback to text parsing
          parse_text_analysis(content, analysis_type)
        end
      rescue JSON::ParserError => e
        Rails.logger.warn "Failed to parse JSON response: #{e.message}"
        parse_text_analysis(response[:content], analysis_type)
      end
    end

    def parse_scoring_response(response)
      return response if response[:error]
      
      begin
        content = response[:content].to_s
        json_match = content.match(/\{.*\}/m)
        
        if json_match
          data = JSON.parse(json_match[0])
          {
            score: data['score'].to_f.clamp(0, 1),
            confidence: data['confidence'].to_f.clamp(0, 1),
            factors: data['factors'] || [],
            recommendations: data['recommendations'] || []
          }
        else
          # Fallback scoring
          { score: 0.5, confidence: 0.5, factors: [], recommendations: [] }
        end
      rescue => e
        Rails.logger.warn "Failed to parse scoring response: #{e.message}"
        { score: 0.5, confidence: 0.5, factors: [], recommendations: [] }
      end
    end

    def parse_entity_response(response)
      return [] if response[:error]
      
      begin
        content = response[:content].to_s
        json_match = content.match(/\{.*\}/m)
        
        if json_match
          data = JSON.parse(json_match[0])
          data['entities'] || []
        else
          []
        end
      rescue => e
        Rails.logger.warn "Failed to parse entity response: #{e.message}"
        []
      end
    end

    def parse_text_analysis(content, analysis_type)
      # Simple text parsing fallback
      case analysis_type
      when :sentiment
        sentiment = case content.downcase
                   when /positive|good|great|excellent/ then 'positive'
                   when /negative|bad|poor|terrible/ then 'negative'
                   when /mixed|both|neutral/ then 'mixed'
                   else 'neutral'
                   end
        { sentiment: sentiment, confidence: 0.6 }
      when :entities
        { entities: [] }
      when :intent
        { intent: 'unknown', confidence: 0.5 }
      when :relevance
        { score: 0.5, factors: [] }
      when :quality
        { score: 0.5, factors: [] }
      else
        {}
      end
    end
  end
end