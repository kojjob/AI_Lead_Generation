module Ai
  class EnhancedAnalysisService
    attr_reader :mention, :options

    ANALYSIS_MODELS = {
      sentiment: 'sentiment_analysis',
      entities: 'entity_extraction',
      intent: 'intent_detection',
      quality: 'quality_assessment',
      relevance: 'relevance_scoring',
      summarization: 'summarization'
    }.freeze

    def initialize(mention, options = {})
      @mention = mention
      @options = options
    end

    def perform
      results = {}
      
      # Perform multi-model analysis
      ANALYSIS_MODELS.each do |key, model_type|
        next if options[:skip]&.include?(key)
        
        ai_model = AiModel.best_for(model_type)
        next unless ai_model
        
        results[key] = perform_analysis(ai_model, key)
      end

      # Combine results into comprehensive analysis
      analysis_result = create_or_update_analysis(results)
      
      # Generate ML scores
      generate_ml_scores(analysis_result)
      
      # Index in Elasticsearch
      index_analysis(analysis_result) if options[:index]
      
      success_result(analysis_result)
    rescue => e
      error_result(e.message)
    end

    private

    def perform_analysis(ai_model, analysis_type)
      case ai_model.provider
      when 'openai'
        perform_openai_analysis(ai_model, analysis_type)
      when 'anthropic'
        perform_anthropic_analysis(ai_model, analysis_type)
      when 'gemini'
        perform_gemini_analysis(ai_model, analysis_type)
      else
        perform_rule_based_analysis(analysis_type)
      end
    end

    def perform_openai_analysis(ai_model, analysis_type)
      client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
      
      prompt = build_analysis_prompt(analysis_type)
      functions = analysis_functions(analysis_type)
      
      parameters = {
        model: ai_model.name,
        messages: [
          { role: "system", content: analysis_system_prompt(analysis_type) },
          { role: "user", content: prompt }
        ],
        **ai_model.configuration.symbolize_keys
      }
      
      parameters[:functions] = functions if functions.present?
      parameters[:function_call] = { name: functions.first[:name] } if functions.present?
      
      response = client.chat(parameters: parameters)
      
      parse_openai_response(response, analysis_type)
    rescue => e
      Rails.logger.error "OpenAI analysis error: #{e.message}"
      perform_rule_based_analysis(analysis_type)
    end

    def perform_anthropic_analysis(ai_model, analysis_type)
      # Anthropic API implementation
      # Would integrate with Claude API
      perform_rule_based_analysis(analysis_type)
    end

    def perform_gemini_analysis(ai_model, analysis_type)
      # Google Gemini API implementation
      perform_rule_based_analysis(analysis_type)
    end

    def perform_rule_based_analysis(analysis_type)
      case analysis_type
      when :sentiment
        analyze_sentiment_rules
      when :entities
        extract_entities_rules
      when :intent
        detect_intent_rules
      when :quality
        assess_quality_rules
      when :relevance
        score_relevance_rules
      when :summarization
        generate_summary_rules
      else
        {}
      end
    end

    def analyze_sentiment_rules
      content = mention.content.to_s.downcase
      
      positive_indicators = %w[great excellent amazing fantastic love best perfect wonderful happy excited]
      negative_indicators = %w[bad terrible awful worst hate horrible poor disappointing frustrated angry]
      
      positive_score = positive_indicators.sum { |word| content.scan(/\b#{word}\b/).count }
      negative_score = negative_indicators.sum { |word| content.scan(/\b#{word}\b/).count }
      
      total = positive_score + negative_score
      
      if total == 0
        sentiment = 'neutral'
        confidence = 0.5
      elsif positive_score > negative_score * 1.5
        sentiment = 'positive'
        confidence = positive_score.to_f / total
      elsif negative_score > positive_score * 1.5
        sentiment = 'negative'
        confidence = negative_score.to_f / total
      else
        sentiment = 'mixed'
        confidence = 0.6
      end
      
      {
        sentiment: sentiment,
        confidence: confidence,
        scores: {
          positive: positive_score,
          negative: negative_score,
          neutral: total == 0 ? 1 : 0
        }
      }
    end

    def extract_entities_rules
      content = mention.content.to_s
      
      entities = []
      
      # Extract emails
      emails = content.scan(/\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/)
      emails.each { |email| entities << { type: 'email', value: email } }
      
      # Extract URLs
      urls = content.scan(/https?:\/\/[^\s]+/)
      urls.each { |url| entities << { type: 'url', value: url } }
      
      # Extract phone numbers
      phones = content.scan(/\+?[\d\s\-\(\)]+/)
                     .select { |p| p.gsub(/\D/, '').length >= 10 }
      phones.each { |phone| entities << { type: 'phone', value: phone } }
      
      # Extract company names (simple heuristic)
      companies = content.scan(/\b[A-Z][a-z]+(?:\s[A-Z][a-z]+)*\s(?:Inc|LLC|Ltd|Corp|Company)\b/)
      companies.each { |company| entities << { type: 'company', value: company } }
      
      # Extract person names (simple heuristic)
      names = content.scan(/\b[A-Z][a-z]+\s[A-Z][a-z]+\b/)
                    .reject { |n| n.split.any? { |w| w.length < 2 } }
      names.each { |name| entities << { type: 'person', value: name } }
      
      entities.uniq
    end

    def detect_intent_rules
      content = mention.content.to_s.downcase
      keyword = mention.keyword&.term&.downcase
      
      intents = []
      confidence = 0.5
      
      # Purchase intent
      if content =~ /\b(buy|purchase|order|price|cost|quote|budget|pay)\b/
        intents << 'purchase_intent'
        confidence = 0.7
      end
      
      # Support intent
      if content =~ /\b(help|support|issue|problem|error|bug|fix|broken)\b/
        intents << 'support_intent'
        confidence = 0.7
      end
      
      # Information seeking
      if content =~ /\b(how|what|when|where|why|guide|tutorial|documentation)\b/
        intents << 'information_seeking'
        confidence = 0.6
      end
      
      # Comparison intent
      if content =~ /\b(vs|versus|compare|comparison|alternative|better|best)\b/
        intents << 'comparison_intent'
        confidence = 0.7
      end
      
      # Recommendation seeking
      if content =~ /\b(recommend|suggestion|advice|should|opinions)\b/
        intents << 'recommendation_seeking'
        confidence = 0.6
      end
      
      {
        primary_intent: intents.first || 'unknown',
        all_intents: intents,
        confidence: confidence,
        keyword_mentioned: keyword && content.include?(keyword)
      }
    end

    def assess_quality_rules
      content = mention.content.to_s
      
      quality_score = 0.0
      factors = []
      
      # Length check
      if content.length > 100
        quality_score += 0.2
        factors << 'adequate_length'
      end
      
      # Has URL
      if content =~ /https?:\/\//
        quality_score += 0.15
        factors << 'includes_links'
      end
      
      # Has structure (paragraphs, sentences)
      if content.scan(/[.!?]/).count > 2
        quality_score += 0.15
        factors << 'well_structured'
      end
      
      # Not spam indicators
      spam_indicators = %w[viagra cialis lottery winner congratulations click here]
      is_spam = spam_indicators.any? { |indicator| content.downcase.include?(indicator) }
      
      if !is_spam
        quality_score += 0.3
        factors << 'not_spam'
      end
      
      # Relevance to keyword
      if mention.keyword && content.downcase.include?(mention.keyword.term.downcase)
        quality_score += 0.2
        factors << 'keyword_relevant'
      end
      
      {
        score: quality_score.clamp(0, 1),
        factors: factors,
        is_spam: is_spam,
        content_length: content.length,
        readability: 'medium' # Would use proper readability scoring
      }
    end

    def score_relevance_rules
      return { score: 0.5, factors: [] } unless mention.keyword
      
      content = mention.content.to_s.downcase
      keyword = mention.keyword.term.downcase
      
      relevance_score = 0.0
      factors = []
      
      # Exact keyword match
      exact_matches = content.scan(/\b#{Regexp.escape(keyword)}\b/).count
      if exact_matches > 0
        relevance_score += [ exact_matches * 0.1, 0.3 ].min
        factors << "exact_matches:#{exact_matches}"
      end
      
      # Partial matches
      if content.include?(keyword)
        relevance_score += 0.2
        factors << 'contains_keyword'
      end
      
      # Related terms (would use word embeddings in production)
      related_terms = mention.keyword.metadata&.dig('related_terms') || []
      related_matches = related_terms.count { |term| content.include?(term.downcase) }
      if related_matches > 0
        relevance_score += [ related_matches * 0.05, 0.2 ].min
        factors << "related_terms:#{related_matches}"
      end
      
      # Context relevance
      if mention.keyword.metadata&.dig('context_words')&.any? { |word| content.include?(word) }
        relevance_score += 0.15
        factors << 'context_match'
      end
      
      # Platform relevance
      platform_weight = { 'twitter' => 0.1, 'linkedin' => 0.15, 'reddit' => 0.1 }[mention.platform] || 0.05
      relevance_score += platform_weight
      factors << "platform:#{mention.platform}"
      
      {
        score: relevance_score.clamp(0, 1),
        factors: factors,
        exact_matches: exact_matches,
        keyword_density: (exact_matches.to_f / content.split.count * 100).round(2)
      }
    end

    def generate_summary_rules
      content = mention.content.to_s
      sentences = content.split(/[.!?]/).map(&:strip).reject(&:empty?)
      
      # Simple extractive summarization
      summary = if sentences.count <= 2
        content
      else
        # Take first and most important sentences
        important_sentences = sentences.select do |sentence|
          mention.keyword && sentence.downcase.include?(mention.keyword.term.downcase)
        end
        
        result = sentences.first(1) + important_sentences.first(1)
        result.uniq.join('. ') + '.'
      end
      
      {
        summary: summary.truncate(500),
        original_length: content.length,
        summary_length: summary.length,
        compression_ratio: (summary.length.to_f / content.length * 100).round(2),
        method: 'extractive'
      }
    end

    def analysis_system_prompt(analysis_type)
      case analysis_type
      when :sentiment
        "You are a sentiment analysis expert. Analyze the emotional tone and sentiment of the given text."
      when :entities
        "You are an entity extraction specialist. Identify and extract all relevant entities from the text."
      when :intent
        "You are an intent detection expert. Identify the primary intent and purpose of the given text."
      when :quality
        "You are a content quality assessor. Evaluate the quality, credibility, and value of the content."
      when :relevance
        "You are a relevance scoring expert. Assess how relevant the content is to the given keyword."
      when :summarization
        "You are a summarization expert. Create concise, informative summaries of the given content."
      else
        "You are an AI analysis assistant. Provide comprehensive analysis of the given content."
      end
    end

    def build_analysis_prompt(analysis_type)
      keyword_context = mention.keyword ? "Keyword: #{mention.keyword.term}" : ""
      
      <<~PROMPT
        Analyze the following content:
        
        #{mention.content}
        
        #{keyword_context}
        
        Platform: #{mention.platform}
        Author: #{mention.author}
        
        Provide a detailed #{analysis_type} analysis.
      PROMPT
    end

    def analysis_functions(analysis_type)
      case analysis_type
      when :sentiment
        [sentiment_function]
      when :entities
        [entities_function]
      when :intent
        [intent_function]
      else
        nil
      end
    end

    def sentiment_function
      {
        name: "analyze_sentiment",
        description: "Analyze the sentiment of the text",
        parameters: {
          type: "object",
          properties: {
            sentiment: { type: "string", enum: ["positive", "negative", "neutral", "mixed"] },
            confidence: { type: "number", minimum: 0, maximum: 1 },
            aspects: {
              type: "array",
              items: {
                type: "object",
                properties: {
                  aspect: { type: "string" },
                  sentiment: { type: "string" },
                  confidence: { type: "number" }
                }
              }
            }
          },
          required: ["sentiment", "confidence"]
        }
      }
    end

    def entities_function
      {
        name: "extract_entities",
        description: "Extract entities from the text",
        parameters: {
          type: "object",
          properties: {
            entities: {
              type: "array",
              items: {
                type: "object",
                properties: {
                  type: { type: "string" },
                  value: { type: "string" },
                  confidence: { type: "number" }
                }
              }
            }
          },
          required: ["entities"]
        }
      }
    end

    def intent_function
      {
        name: "detect_intent",
        description: "Detect the intent of the text",
        parameters: {
          type: "object",
          properties: {
            primary_intent: { type: "string" },
            secondary_intents: { type: "array", items: { type: "string" } },
            confidence: { type: "number", minimum: 0, maximum: 1 },
            urgency: { type: "string", enum: ["high", "medium", "low"] }
          },
          required: ["primary_intent", "confidence"]
        }
      }
    end

    def parse_openai_response(response, analysis_type)
      if response.dig('choices', 0, 'message', 'function_call')
        function_response = response.dig('choices', 0, 'message', 'function_call', 'arguments')
        JSON.parse(function_response).symbolize_keys
      else
        content = response.dig('choices', 0, 'message', 'content')
        parse_text_response(content, analysis_type)
      end
    rescue => e
      Rails.logger.error "Failed to parse OpenAI response: #{e.message}"
      perform_rule_based_analysis(analysis_type)
    end

    def parse_text_response(content, analysis_type)
      # Attempt to parse as JSON first
      JSON.parse(content).symbolize_keys
    rescue
      # Fallback to text parsing
      perform_rule_based_analysis(analysis_type)
    end

    def create_or_update_analysis(results)
      analysis = mention.analysis_result || mention.build_analysis_result
      
      # Combine all analysis results
      analysis.sentiment = results.dig(:sentiment, :sentiment) || 'neutral'
      analysis.entities = results.dig(:entities) || []
      analysis.intent = results.dig(:intent, :primary_intent)
      analysis.topics = extract_topics(results)
      analysis.summary = results.dig(:summarization, :summary) || mention.content.truncate(200)
      
      # Calculate scores
      analysis.relevance_score = results.dig(:relevance, :score) || 0.5
      analysis.confidence_score = calculate_overall_confidence(results)
      analysis.quality_score = results.dig(:quality, :score) || 0.5
      
      # Metadata
      analysis.ai_model_used = results.map { |k, v| v[:model] }.compact.first || 'rule_based'
      analysis.processing_time = results.map { |k, v| v[:time] }.compact.sum
      analysis.metadata = {
        analysis_results: results,
        analyzed_at: Time.current,
        version: '2.0'
      }
      
      analysis.save!
      analysis
    end

    def extract_topics(results)
      topics = []
      
      # Extract from entities
      if results[:entities].is_a?(Array)
        topics += results[:entities]
                   .select { |e| e[:type] == 'topic' }
                   .map { |e| e[:value] }
      end
      
      # Extract from content analysis
      if results[:quality]
        topics += results.dig(:quality, :topics) || []
      end
      
      topics.uniq
    end

    def calculate_overall_confidence(results)
      confidences = results.values.map { |r| r[:confidence] }.compact
      return 0.5 if confidences.empty?
      
      confidences.sum.to_f / confidences.count
    end

    def generate_ml_scores(analysis_result)
      # Generate various ML scores for the analysis
      scoring_service = Ai::MlScoringService.new(
        analysis_result,
        'quality_assessment',
        threshold: 0.6
      )
      scoring_service.perform
      
      # Generate relevance score
      if mention.keyword
        relevance_scoring = Ai::MlScoringService.new(
          analysis_result,
          'relevance_scoring',
          keyword: mention.keyword
        )
        relevance_scoring.perform
      end
    end

    def index_analysis(analysis_result)
      index = SearchIndex.find_by(index_type: 'analysis_results', status: 'active')
      return unless index
      
      document = {
        id: analysis_result.id,
        mention_id: mention.id,
        summary: analysis_result.summary,
        sentiment: analysis_result.sentiment,
        entities: analysis_result.entities,
        topics: analysis_result.topics,
        intent: analysis_result.intent,
        relevance_score: analysis_result.relevance_score,
        confidence_score: analysis_result.confidence_score,
        quality_score: analysis_result.quality_score,
        analyzed_at: analysis_result.created_at,
        ai_model: analysis_result.ai_model_used,
        keyword: mention.keyword&.term,
        platform: mention.platform
      }
      
      index.elasticsearch_client.index(
        index: index.elasticsearch_index_name || index.name,
        id: analysis_result.id,
        body: document
      )
    rescue => e
      Rails.logger.error "Failed to index analysis: #{e.message}"
    end

    def success_result(analysis_result)
      {
        success: true,
        analysis: analysis_result,
        sentiment: analysis_result.sentiment,
        relevance_score: analysis_result.relevance_score,
        confidence: analysis_result.confidence_score
      }
    end

    def error_result(message)
      {
        success: false,
        error: message,
        analysis: nil
      }
    end
  end
end