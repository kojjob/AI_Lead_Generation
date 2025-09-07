class KeywordRecommendationService
  # Keyword categories and their performance indicators
  KEYWORD_CATEGORIES = {
    buying_intent: {
      patterns: %w[buy purchase looking for need want shopping for in the market for],
      weight: 1.0,
      priority: "high"
    },
    comparison: {
      patterns: %w[vs versus compare comparison alternative best top review],
      weight: 0.8,
      priority: "high"
    },
    problem_solving: {
      patterns: %w[problem issue challenge help solution fix solve how to],
      weight: 0.7,
      priority: "medium"
    },
    informational: {
      patterns: %w[what is how does explain tutorial guide learn about],
      weight: 0.5,
      priority: "medium"
    },
    brand_mentions: {
      patterns: %w[company brand service product],
      weight: 0.6,
      priority: "low"
    }
  }.freeze

  def initialize(user)
    @user = user
    @existing_keywords = user.keywords.pluck(:keyword).map(&:downcase)
  end

  def generate_recommendations(limit: 10)
    recommendations = []

    # Analyze existing keyword performance
    performance_insights = analyze_existing_performance

    # Generate recommendations based on different strategies
    recommendations.concat(generate_expansion_keywords)
    recommendations.concat(generate_long_tail_keywords)
    recommendations.concat(generate_competitor_keywords)
    recommendations.concat(generate_trending_keywords)
    recommendations.concat(generate_intent_based_keywords)

    # Score and rank recommendations
    scored_recommendations = score_recommendations(recommendations)

    # Remove duplicates and existing keywords
    unique_recommendations = filter_and_deduplicate(scored_recommendations)

    {
      recommendations: unique_recommendations.first(limit),
      performance_insights: performance_insights,
      total_analyzed: recommendations.length,
      categories_covered: get_categories_covered(unique_recommendations)
    }
  end

  def self.generate_for_user(user, limit: 10)
    new(user).generate_recommendations(limit: limit)
  end

  def analyze_keyword_potential(keyword_text)
    return default_analysis unless keyword_text.present?

    {
      keyword: keyword_text,
      category: categorize_keyword(keyword_text),
      intent_score: calculate_intent_score(keyword_text),
      competition_level: estimate_competition(keyword_text),
      conversion_potential: estimate_conversion_potential(keyword_text),
      search_volume_estimate: estimate_search_volume(keyword_text),
      recommended_priority: recommend_priority(keyword_text)
    }
  end

  private

  def analyze_existing_performance
    return {} if @user.keywords.empty?

    keywords_with_stats = @user.keywords.includes(:mentions, :leads)

    performance_data = keywords_with_stats.map do |keyword|
      mentions_count = keyword.mentions.count
      leads_count = keyword.leads.count
      conversion_rate = mentions_count > 0 ? (leads_count.to_f / mentions_count) : 0

      {
        keyword: keyword.keyword,
        mentions: mentions_count,
        leads: leads_count,
        conversion_rate: conversion_rate,
        category: categorize_keyword(keyword.keyword)
      }
    end

    {
      total_keywords: keywords_with_stats.count,
      avg_conversion_rate: performance_data.map { |k| k[:conversion_rate] }.sum / performance_data.length,
      best_performing: performance_data.max_by { |k| k[:conversion_rate] },
      worst_performing: performance_data.min_by { |k| k[:conversion_rate] },
      category_performance: analyze_category_performance(performance_data)
    }
  end

  def generate_expansion_keywords
    return [] if @existing_keywords.empty?

    expansions = []

    @existing_keywords.each do |keyword|
      # Add modifiers
      expansions.concat(add_modifiers(keyword))

      # Add location-based variations
      expansions.concat(add_location_variations(keyword))

      # Add question variations
      expansions.concat(add_question_variations(keyword))
    end

    expansions.uniq
  end

  def generate_long_tail_keywords
    long_tail = []

    @existing_keywords.each do |keyword|
      # Add specific use cases
      long_tail << "#{keyword} for small business"
      long_tail << "#{keyword} for startups"
      long_tail << "affordable #{keyword}"
      long_tail << "enterprise #{keyword}"
      long_tail << "#{keyword} implementation"
      long_tail << "#{keyword} best practices"
    end

    long_tail.uniq
  end

  def generate_competitor_keywords
    # This would typically integrate with competitor analysis tools
    # For now, generate common competitive keywords
    competitive = []

    @existing_keywords.each do |keyword|
      competitive << "#{keyword} alternative"
      competitive << "#{keyword} competitor"
      competitive << "#{keyword} vs"
      competitive << "better than #{keyword}"
      competitive << "#{keyword} comparison"
    end

    competitive.uniq
  end

  def generate_trending_keywords
    # This would integrate with trending topic APIs
    # For now, generate based on current business trends
    trending_modifiers = [
      "AI-powered", "automated", "cloud-based", "remote", "digital",
      "sustainable", "eco-friendly", "mobile", "real-time", "data-driven"
    ]

    trending = []
    @existing_keywords.each do |keyword|
      trending_modifiers.each do |modifier|
        trending << "#{modifier} #{keyword}"
      end
    end

    trending.uniq
  end

  def generate_intent_based_keywords
    intent_keywords = []

    KEYWORD_CATEGORIES.each do |category, data|
      next if category == :brand_mentions

      @existing_keywords.each do |keyword|
        data[:patterns].each do |pattern|
          intent_keywords << "#{pattern} #{keyword}"
          intent_keywords << "#{keyword} #{pattern}"
        end
      end
    end

    intent_keywords.uniq
  end

  def add_modifiers(keyword)
    modifiers = [
      "best", "top", "cheap", "affordable", "premium", "professional",
      "enterprise", "small business", "free", "open source", "custom"
    ]

    modifiers.map { |modifier| "#{modifier} #{keyword}" }
  end

  def add_location_variations(keyword)
    # Add common location modifiers
    locations = [ "near me", "local", "online", "remote" ]
    locations.map { |location| "#{keyword} #{location}" }
  end

  def add_question_variations(keyword)
    question_starters = [
      "how to choose", "what is the best", "how much does", "where to find",
      "how to implement", "why use", "when to use"
    ]

    question_starters.map { |starter| "#{starter} #{keyword}" }
  end

  def score_recommendations(recommendations)
    recommendations.map do |keyword|
      score = calculate_keyword_score(keyword)

      {
        keyword: keyword,
        score: score,
        category: categorize_keyword(keyword),
        intent_score: calculate_intent_score(keyword),
        competition_estimate: estimate_competition(keyword),
        priority: recommend_priority(keyword)
      }
    end
  end

  def calculate_keyword_score(keyword)
    score = 0.0

    # Intent score (higher for buying intent)
    intent_score = calculate_intent_score(keyword)
    score += intent_score * 0.4

    # Length bonus (long-tail keywords often convert better)
    word_count = keyword.split.length
    length_bonus = case word_count
    when 3..4
      0.3
    when 5..6
      0.2
    else
      0.1
    end
    score += length_bonus

    # Category bonus
    category = categorize_keyword(keyword)
    category_weight = KEYWORD_CATEGORIES.dig(category, :weight) || 0.5
    score += category_weight * 0.3

    [ score, 1.0 ].min
  end

  def categorize_keyword(keyword)
    keyword_lower = keyword.downcase

    KEYWORD_CATEGORIES.each do |category, data|
      if data[:patterns].any? { |pattern| keyword_lower.include?(pattern) }
        return category
      end
    end

    :general
  end

  def calculate_intent_score(keyword)
    keyword_lower = keyword.downcase

    # High intent indicators
    high_intent = %w[buy purchase price cost quote estimate hire]
    medium_intent = %w[compare review best top solution service]
    low_intent = %w[what how learn about tutorial guide]

    if high_intent.any? { |term| keyword_lower.include?(term) }
      1.0
    elsif medium_intent.any? { |term| keyword_lower.include?(term) }
      0.7
    elsif low_intent.any? { |term| keyword_lower.include?(term) }
      0.4
    else
      0.5
    end
  end

  def estimate_competition(keyword)
    # Simple competition estimation based on keyword characteristics
    word_count = keyword.split.length

    case word_count
    when 1..2
      "high"
    when 3..4
      "medium"
    else
      "low"
    end
  end

  def estimate_conversion_potential(keyword)
    intent_score = calculate_intent_score(keyword)
    competition = estimate_competition(keyword)

    base_potential = intent_score

    # Adjust for competition
    case competition
    when "low"
      base_potential += 0.2
    when "high"
      base_potential -= 0.2
    end

    [ base_potential, 1.0 ].min
  end

  def estimate_search_volume(keyword)
    # Simplified search volume estimation
    word_count = keyword.split.length

    case word_count
    when 1..2
      "high"
    when 3..4
      "medium"
    else
      "low"
    end
  end

  def recommend_priority(keyword)
    score = calculate_keyword_score(keyword)

    case score
    when 0.8..1.0
      "high"
    when 0.6..0.8
      "medium"
    else
      "low"
    end
  end

  def filter_and_deduplicate(recommendations)
    # Remove existing keywords and duplicates
    filtered = recommendations.reject do |rec|
      @existing_keywords.include?(rec[:keyword].downcase)
    end

    # Remove duplicates
    seen = Set.new
    filtered.select do |rec|
      key = rec[:keyword].downcase
      if seen.include?(key)
        false
      else
        seen.add(key)
        true
      end
    end.sort_by { |rec| -rec[:score] }
  end

  def analyze_category_performance(performance_data)
    categories = performance_data.group_by { |k| k[:category] }

    categories.transform_values do |keywords|
      {
        count: keywords.length,
        avg_conversion_rate: keywords.map { |k| k[:conversion_rate] }.sum / keywords.length,
        total_mentions: keywords.sum { |k| k[:mentions] },
        total_leads: keywords.sum { |k| k[:leads] }
      }
    end
  end

  def get_categories_covered(recommendations)
    recommendations.map { |rec| rec[:category] }.uniq
  end

  def default_analysis
    {
      keyword: "",
      category: :general,
      intent_score: 0.5,
      competition_level: "unknown",
      conversion_potential: 0.5,
      search_volume_estimate: "unknown",
      recommended_priority: "low"
    }
  end
end
