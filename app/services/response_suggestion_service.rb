class ResponseSuggestionService
  include HTTParty

  # Response templates categorized by intent and sentiment
  RESPONSE_TEMPLATES = {
    positive_inquiry: [
      "Hi {name}! I'd be happy to help you with {topic}. {company} specializes in exactly what you're looking for. Would you like to schedule a quick call to discuss your needs?",
      "Thanks for your interest in {topic}! I noticed your question and thought I could provide some insights. {company} has helped many clients with similar challenges. Mind if I share some relevant information?",
      "Great question about {topic}! I've been working in this space for years and would love to help. {company} offers solutions that might be perfect for your situation. Can I send you some details?"
    ],
    neutral_inquiry: [
      "Hi {name}, I saw your question about {topic} and thought I might be able to help. {company} has experience in this area. Would you be interested in learning more?",
      "I noticed your post about {topic}. {company} works with clients facing similar challenges. Happy to share some insights if you're interested.",
      "Regarding your question about {topic} - {company} might have some solutions that could help. Would you like to connect and discuss?"
    ],
    negative_sentiment: [
      "I understand your frustration with {topic}. Many of our clients at {company} have faced similar challenges. We've developed approaches that address these exact issues. Would you be open to a brief conversation about potential solutions?",
      "I hear you on the challenges with {topic}. {company} has helped others overcome similar obstacles. If you're interested, I'd be happy to share how we've solved this for other clients.",
      "Your concerns about {topic} are valid - it's a common pain point. {company} specializes in addressing these issues. Would you like to explore some alternatives?"
    ],
    buying_intent: [
      "Hi {name}! I see you're looking for {topic} solutions. {company} offers exactly what you need with {unique_value}. I'd love to show you how we can help. Are you available for a quick demo this week?",
      "Perfect timing! {company} specializes in {topic} and we have some exciting options that might interest you. Would you like to see how our solution compares to what you're currently considering?",
      "I noticed you're evaluating {topic} options. {company} has a proven track record in this space with {social_proof}. Would you be interested in a personalized consultation?"
    ],
    comparison_request: [
      "Great question about {topic} options! {company} offers {unique_differentiator} that sets us apart from alternatives. I'd be happy to provide a detailed comparison. Would a brief call work for you?",
      "I can help you compare {topic} solutions! {company} has unique advantages including {key_benefit}. Would you like me to send you a comparison guide or schedule a quick overview call?",
      "Comparing {topic} providers is smart! {company} stands out because of {competitive_advantage}. I'd love to show you the differences. Are you free for a 15-minute call this week?"
    ]
  }.freeze

  # Intent detection patterns
  INTENT_PATTERNS = {
    buying_intent: [
      /\b(buy|purchase|looking for|need|want|shopping for|in the market for)\b/i,
      /\b(price|cost|budget|quote|estimate)\b/i,
      /\b(best|top|recommend|suggestion)\b/i
    ],
    comparison_request: [
      /\b(compare|comparison|vs|versus|alternative|option)\b/i,
      /\b(which is better|what's the difference|pros and cons)\b/i,
      /\b(review|reviews|rating|ratings)\b/i
    ],
    problem_statement: [
      /\b(problem|issue|challenge|struggle|difficulty)\b/i,
      /\b(help|solution|fix|solve|resolve)\b/i,
      /\b(frustrated|annoyed|disappointed)\b/i
    ],
    information_seeking: [
      /\b(how to|how do|what is|what are|explain|tutorial)\b/i,
      /\b(learn|understand|know|find out)\b/i,
      /\b(question|ask|wondering)\b/i
    ]
  }.freeze

  def initialize(mention, user_context = {})
    @mention = mention
    @user_context = user_context
    @company = user_context[:company] || "our company"
    @user_name = user_context[:name] || "there"
  end

  def generate_suggestions(count: 3)
    return default_suggestions if @mention.content.blank?

    intent = detect_intent(@mention.content)
    sentiment = get_sentiment
    context = extract_context
    
    suggestions = generate_contextual_responses(intent, sentiment, context, count)
    
    {
      suggestions: suggestions,
      intent: intent,
      sentiment: sentiment,
      context: context,
      confidence: calculate_confidence(intent, sentiment, context)
    }
  end

  def self.generate_for_mention(mention, user_context = {}, count: 3)
    new(mention, user_context).generate_suggestions(count: count)
  end

  private

  def detect_intent(content)
    content_lower = content.downcase
    
    INTENT_PATTERNS.each do |intent, patterns|
      if patterns.any? { |pattern| content_lower.match?(pattern) }
        return intent
      end
    end
    
    :general_inquiry
  end

  def get_sentiment
    if @mention.analysis_result&.sentiment_score
      score = @mention.analysis_result.sentiment_score
      case score
      when 0.2..1.0
        :positive
      when -1.0..-0.2
        :negative
      else
        :neutral
      end
    else
      # Fallback sentiment detection
      detect_basic_sentiment(@mention.content)
    end
  end

  def detect_basic_sentiment(content)
    positive_words = %w[great good love like amazing excellent wonderful fantastic happy excited]
    negative_words = %w[bad terrible awful hate dislike horrible disappointed frustrated angry]
    
    words = content.downcase.split(/\W+/)
    positive_count = words.count { |word| positive_words.include?(word) }
    negative_count = words.count { |word| negative_words.include?(word) }
    
    if positive_count > negative_count
      :positive
    elsif negative_count > positive_count
      :negative
    else
      :neutral
    end
  end

  def extract_context
    content = @mention.content
    keyword = @mention.keyword&.keyword
    
    {
      topic: keyword || extract_topic_from_content(content),
      name: extract_name_from_content(content),
      platform: @mention.platform || 'social media',
      urgency: detect_urgency(content),
      specific_needs: extract_specific_needs(content)
    }
  end

  def extract_topic_from_content(content)
    # Simple topic extraction - in production, use NLP
    @mention.keyword&.keyword || "your inquiry"
  end

  def extract_name_from_content(content)
    # Try to extract name from @mentions or content
    # This is a simplified implementation
    @user_name
  end

  def detect_urgency(content)
    urgent_indicators = %w[urgent asap immediately soon quickly fast now today]
    content_lower = content.downcase
    
    if urgent_indicators.any? { |indicator| content_lower.include?(indicator) }
      :high
    elsif content_lower.match?(/\b(this week|soon|quickly)\b/)
      :medium
    else
      :low
    end
  end

  def extract_specific_needs(content)
    # Extract specific requirements or pain points
    needs = []
    
    # Budget indicators
    needs << "budget-conscious" if content.downcase.match?(/\b(cheap|affordable|budget|low cost)\b/)
    
    # Quality indicators
    needs << "quality-focused" if content.downcase.match?(/\b(quality|premium|best|top)\b/)
    
    # Speed indicators
    needs << "time-sensitive" if content.downcase.match?(/\b(fast|quick|urgent|asap)\b/)
    
    needs
  end

  def generate_contextual_responses(intent, sentiment, context, count)
    # Determine response category
    response_category = determine_response_category(intent, sentiment)
    
    # Get base templates
    templates = RESPONSE_TEMPLATES[response_category] || RESPONSE_TEMPLATES[:neutral_inquiry]
    
    # Generate personalized responses
    responses = templates.first(count).map do |template|
      personalize_template(template, context)
    end
    
    # Add AI-generated response if available
    if responses.length < count
      ai_response = generate_ai_response(intent, sentiment, context)
      responses << ai_response if ai_response
    end
    
    responses.first(count).map.with_index do |response, index|
      {
        text: response,
        tone: determine_tone(response_category, sentiment),
        priority: calculate_priority(intent, sentiment, index),
        personalization_level: calculate_personalization_level(context),
        suggested_timing: suggest_timing(context[:urgency])
      }
    end
  end

  def determine_response_category(intent, sentiment)
    case intent
    when :buying_intent
      :buying_intent
    when :comparison_request
      :comparison_request
    when :problem_statement
      sentiment == :negative ? :negative_sentiment : :neutral_inquiry
    else
      case sentiment
      when :positive
        :positive_inquiry
      when :negative
        :negative_sentiment
      else
        :neutral_inquiry
      end
    end
  end

  def personalize_template(template, context)
    personalized = template.dup
    
    # Replace placeholders
    personalized.gsub!('{name}', context[:name] || 'there')
    personalized.gsub!('{topic}', context[:topic] || 'your inquiry')
    personalized.gsub!('{company}', @company)
    
    # Add context-specific elements
    personalized.gsub!('{unique_value}', generate_unique_value_prop(context))
    personalized.gsub!('{social_proof}', generate_social_proof)
    personalized.gsub!('{key_benefit}', generate_key_benefit(context))
    personalized.gsub!('{unique_differentiator}', generate_differentiator)
    personalized.gsub!('{competitive_advantage}', generate_competitive_advantage)
    
    personalized
  end

  def generate_unique_value_prop(context)
    if context[:specific_needs].include?("budget-conscious")
      "cost-effective solutions"
    elsif context[:specific_needs].include?("quality-focused")
      "premium, high-quality service"
    elsif context[:specific_needs].include?("time-sensitive")
      "rapid implementation and quick results"
    else
      "tailored solutions for your specific needs"
    end
  end

  def generate_social_proof
    examples = [
      "over 500 satisfied clients",
      "a 95% customer satisfaction rate",
      "proven results across multiple industries",
      "award-winning solutions"
    ]
    examples.sample
  end

  def generate_key_benefit(context)
    benefits = [
      "24/7 support and rapid response times",
      "industry-leading expertise and innovation",
      "customizable solutions that scale with your business",
      "transparent pricing with no hidden fees"
    ]
    benefits.sample
  end

  def generate_differentiator
    differentiators = [
      "our proprietary technology and proven methodology",
      "personalized service and dedicated account management",
      "comprehensive solutions that address all your needs",
      "industry expertise and deep domain knowledge"
    ]
    differentiators.sample
  end

  def generate_competitive_advantage
    advantages = [
      "faster implementation times and better ROI",
      "more comprehensive features at competitive pricing",
      "superior customer support and ongoing partnership",
      "proven track record and industry recognition"
    ]
    advantages.sample
  end

  def generate_ai_response(intent, sentiment, context)
    # Placeholder for AI-generated response using OpenAI or similar
    # This would make an API call to generate a custom response
    nil
  end

  def determine_tone(category, sentiment)
    case category
    when :buying_intent
      'enthusiastic'
    when :negative_sentiment
      'empathetic'
    when :positive_inquiry
      'friendly'
    else
      'professional'
    end
  end

  def calculate_priority(intent, sentiment, index)
    base_priority = case intent
    when :buying_intent
      'high'
    when :comparison_request
      'medium'
    else
      'low'
    end
    
    # Adjust for sentiment
    if sentiment == :positive && base_priority != 'high'
      base_priority = 'medium'
    end
    
    # First suggestion gets higher priority
    index == 0 ? base_priority : 'low'
  end

  def calculate_personalization_level(context)
    level = 0
    level += 1 if context[:name] != @user_name
    level += 1 if context[:topic] != "your inquiry"
    level += 1 if context[:specific_needs].any?
    level += 1 if context[:urgency] != :low
    
    case level
    when 0..1
      'low'
    when 2..3
      'medium'
    else
      'high'
    end
  end

  def suggest_timing(urgency)
    case urgency
    when :high
      'within 1 hour'
    when :medium
      'within 4 hours'
    else
      'within 24 hours'
    end
  end

  def calculate_confidence(intent, sentiment, context)
    confidence = 0.5
    
    confidence += 0.2 if intent != :general_inquiry
    confidence += 0.1 if sentiment != :neutral
    confidence += 0.1 if context[:topic] != "your inquiry"
    confidence += 0.1 if context[:specific_needs].any?
    
    [confidence, 1.0].min
  end

  def default_suggestions
    {
      suggestions: [
        {
          text: "Thank you for your interest! I'd be happy to help you learn more about our solutions. Would you like to schedule a brief call to discuss your needs?",
          tone: 'professional',
          priority: 'medium',
          personalization_level: 'low',
          suggested_timing: 'within 24 hours'
        }
      ],
      intent: :general_inquiry,
      sentiment: :neutral,
      context: {},
      confidence: 0.3
    }
  end
end
