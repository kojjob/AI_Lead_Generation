class LeadQualityPredictionService
  # Lead quality scoring factors and weights
  SCORING_FACTORS = {
    sentiment_score: 0.25,      # Positive sentiment indicates higher quality
    engagement_level: 0.20,     # Comments, likes, shares indicate engagement
    profile_completeness: 0.15, # Complete profiles are more likely to convert
    platform_authority: 0.15,   # Verified accounts, follower count
    content_relevance: 0.10,    # How relevant the mention is to keywords
    timing_factor: 0.10,        # Recent mentions are more valuable
    historical_conversion: 0.05 # Past conversion rates for similar leads
  }.freeze

  def initialize(lead)
    @lead = lead
    @mention = lead.mention
    @keyword = @mention&.keyword
    @user = lead.user
  end

  def predict_quality
    return default_prediction unless @mention && @keyword

    factors = calculate_all_factors
    quality_score = calculate_weighted_score(factors)
    quality_tier = determine_quality_tier(quality_score)
    conversion_probability = estimate_conversion_probability(quality_score, factors)

    {
      quality_score: quality_score.round(3),
      quality_tier: quality_tier,
      conversion_probability: conversion_probability.round(3),
      factors: factors,
      recommendations: generate_recommendations(factors, quality_tier),
      confidence: calculate_confidence(factors)
    }
  end

  def self.predict_batch(leads)
    leads.map { |lead| new(lead).predict_quality }
  end

  def self.update_lead_scores(leads)
    leads.each do |lead|
      prediction = new(lead).predict_quality
      lead.update!(
        quality_score: prediction[:quality_score],
        conversion_probability: prediction[:conversion_probability],
        quality_tier: prediction[:quality_tier]
      )
    end
  end

  private

  def calculate_all_factors
    {
      sentiment_score: calculate_sentiment_factor,
      engagement_level: calculate_engagement_factor,
      profile_completeness: calculate_profile_factor,
      platform_authority: calculate_authority_factor,
      content_relevance: calculate_relevance_factor,
      timing_factor: calculate_timing_factor,
      historical_conversion: calculate_historical_factor
    }
  end

  def calculate_sentiment_factor
    return 0.5 unless @mention.analysis_result&.sentiment_score

    # Convert sentiment score (-1 to 1) to quality factor (0 to 1)
    sentiment = @mention.analysis_result.sentiment_score
    [ (sentiment + 1) / 2, 1.0 ].min
  end

  def calculate_engagement_factor
    # Analyze engagement metrics from the mention
    engagement_indicators = extract_engagement_metrics

    base_score = 0.3 # Default for having any mention

    # Add points for various engagement types
    base_score += 0.2 if engagement_indicators[:has_comments]
    base_score += 0.2 if engagement_indicators[:has_likes]
    base_score += 0.1 if engagement_indicators[:has_shares]
    base_score += 0.1 if engagement_indicators[:is_reply]
    base_score += 0.1 if engagement_indicators[:mentions_brand]

    [ base_score, 1.0 ].min
  end

  def calculate_profile_factor
    # Analyze profile completeness from mention metadata
    profile_data = extract_profile_data

    completeness_score = 0.0
    completeness_score += 0.2 if profile_data[:has_bio]
    completeness_score += 0.2 if profile_data[:has_profile_image]
    completeness_score += 0.2 if profile_data[:has_location]
    completeness_score += 0.2 if profile_data[:has_website]
    completeness_score += 0.2 if profile_data[:account_age_months] > 6

    completeness_score
  end

  def calculate_authority_factor
    # Calculate platform authority based on follower count, verification, etc.
    authority_data = extract_authority_data

    authority_score = 0.1 # Base score for having an account

    # Follower count factor (logarithmic scale)
    if authority_data[:follower_count] > 0
      follower_factor = Math.log10(authority_data[:follower_count] + 1) / 6 # Max at 1M followers
      authority_score += [ follower_factor * 0.4, 0.4 ].min
    end

    authority_score += 0.3 if authority_data[:is_verified]
    authority_score += 0.2 if authority_data[:posting_frequency] == "regular"

    [ authority_score, 1.0 ].min
  end

  def calculate_relevance_factor
    # Analyze how relevant the mention is to the keyword
    return 0.5 unless @mention.content && @keyword.keyword

    content = @mention.content.downcase
    keyword_text = @keyword.keyword.downcase

    relevance_score = 0.0

    # Direct keyword match
    relevance_score += 0.4 if content.include?(keyword_text)

    # Related terms (simple implementation)
    related_terms = generate_related_terms(keyword_text)
    related_matches = related_terms.count { |term| content.include?(term) }
    relevance_score += [ related_matches * 0.1, 0.3 ].min

    # Context analysis (basic implementation)
    relevance_score += 0.3 if analyze_context_relevance(content, keyword_text)

    [ relevance_score, 1.0 ].min
  end

  def calculate_timing_factor
    # Recent mentions are more valuable
    return 0.5 unless @mention.posted_at

    hours_ago = (Time.current - @mention.posted_at) / 1.hour

    case hours_ago
    when 0..24
      1.0 # Very recent
    when 24..72
      0.8 # Recent
    when 72..168
      0.6 # This week
    when 168..720
      0.4 # This month
    else
      0.2 # Older
    end
  end

  def calculate_historical_factor
    # Analyze historical conversion rates for similar leads
    similar_leads = find_similar_leads
    return 0.5 if similar_leads.empty?

    converted_count = similar_leads.where(status: "converted").count
    total_count = similar_leads.count

    return 0.5 if total_count == 0

    conversion_rate = converted_count.to_f / total_count
    [ conversion_rate, 1.0 ].min
  end

  def calculate_weighted_score(factors)
    total_score = 0.0

    SCORING_FACTORS.each do |factor, weight|
      factor_score = factors[factor] || 0.5
      total_score += factor_score * weight
    end

    total_score
  end

  def determine_quality_tier(score)
    case score
    when 0.8..1.0
      "high"
    when 0.6..0.8
      "medium"
    when 0.4..0.6
      "low"
    else
      "very_low"
    end
  end

  def estimate_conversion_probability(quality_score, factors)
    # Base probability from quality score
    base_probability = quality_score * 0.7

    # Adjust based on specific factors
    adjustments = 0.0
    adjustments += 0.1 if factors[:sentiment_score] > 0.8
    adjustments += 0.1 if factors[:engagement_level] > 0.7
    adjustments += 0.05 if factors[:platform_authority] > 0.6
    adjustments -= 0.1 if factors[:timing_factor] < 0.3

    final_probability = base_probability + adjustments
    [ final_probability, 1.0 ].min
  end

  def calculate_confidence(factors)
    # Confidence based on data availability and quality
    data_points = factors.values.count { |v| v != 0.5 } # Non-default values
    total_factors = factors.size

    base_confidence = data_points.to_f / total_factors

    # Adjust for specific high-confidence indicators
    base_confidence += 0.1 if @mention.analysis_result&.sentiment_score
    base_confidence += 0.1 if extract_engagement_metrics.values.any?

    [ base_confidence, 1.0 ].min
  end

  def generate_recommendations(factors, quality_tier)
    recommendations = []

    case quality_tier
    when "high"
      recommendations << "Priority lead - contact immediately"
      recommendations << "Personalize outreach based on positive sentiment" if factors[:sentiment_score] > 0.8
    when "medium"
      recommendations << "Good potential - follow up within 24 hours"
      recommendations << "Research profile before contacting" if factors[:profile_completeness] < 0.6
    when "low"
      recommendations << "Monitor for additional engagement before contacting"
      recommendations << "Consider automated nurturing sequence"
    else
      recommendations << "Low priority - add to general nurturing campaign"
    end

    # Factor-specific recommendations
    recommendations << "Leverage positive sentiment in messaging" if factors[:sentiment_score] > 0.7
    recommendations << "Engage with their content first" if factors[:engagement_level] > 0.7
    recommendations << "Time-sensitive - mention is very recent" if factors[:timing_factor] > 0.9

    recommendations
  end

  def extract_engagement_metrics
    # Extract engagement data from mention content/metadata
    content = @mention.content || ""

    {
      has_comments: content.include?("comment") || content.include?("reply"),
      has_likes: content.include?("like") || content.include?("love"),
      has_shares: content.include?("share") || content.include?("retweet"),
      is_reply: content.include?("@") || content.include?("reply"),
      mentions_brand: content.downcase.include?(@user.company&.downcase || "")
    }
  end

  def extract_profile_data
    # Extract profile data from mention metadata
    # This would typically come from the API response
    {
      has_bio: true, # Default assumptions - would be populated from API
      has_profile_image: true,
      has_location: false,
      has_website: false,
      account_age_months: 12
    }
  end

  def extract_authority_data
    # Extract authority indicators from mention metadata
    {
      follower_count: 100, # Would come from API
      is_verified: false,
      posting_frequency: "regular"
    }
  end

  def generate_related_terms(keyword)
    # Simple related terms generation
    # In production, this could use NLP libraries or APIs
    base_terms = keyword.split(/\s+/)
    related = []

    base_terms.each do |term|
      related << "#{term}s" # Plural
      related << "#{term}ing" # Gerund
      related << "best #{term}" # Qualifier
    end

    related.uniq
  end

  def analyze_context_relevance(content, keyword)
    # Basic context analysis
    # Look for buying intent keywords
    intent_keywords = %w[buy purchase need want looking for recommend best price]
    intent_keywords.any? { |intent| content.include?(intent) }
  end

  def find_similar_leads
    # Find leads with similar characteristics for historical analysis
    @user.leads
         .joins(:mention)
         .where(mentions: { keyword_id: @keyword.id })
         .where.not(id: @lead.id)
         .limit(50)
  end

  def default_prediction
    {
      quality_score: 0.5,
      quality_tier: "unknown",
      conversion_probability: 0.3,
      factors: {},
      recommendations: [ "Insufficient data for prediction" ],
      confidence: 0.0
    }
  end
end
