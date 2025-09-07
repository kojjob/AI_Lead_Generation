module Ai
  class IntelligenceController < ApplicationController
  before_action :authenticate_user!
  before_action :set_resource, only: [:analyze, :score, :search]

  def index
    @ai_models = AiModel.enabled.ordered_by_priority
    @search_indices = SearchIndex.active
    @recent_scores = current_user.leads
                                 .joins(:ml_scores)
                                 .select('leads.*, ml_scores.*')
                                 .order('ml_scores.created_at DESC')
                                 .limit(10)
    
    @statistics = {
      total_analyses: current_user.mentions.joins(:analysis_result).count,
      total_scores: MlScore.joins("INNER JOIN leads ON leads.id = ml_scores.scoreable_id AND ml_scores.scoreable_type = 'Lead'")
                          .where(leads: { user_id: current_user.id })
                          .count,
      avg_confidence: MlScore.joins("INNER JOIN leads ON leads.id = ml_scores.scoreable_id AND ml_scores.scoreable_type = 'Lead'")
                             .where(leads: { user_id: current_user.id })
                             .average(:confidence) || 0,
      models_used: AiModel.enabled.count
    }
  end

  def analyze
    service = Ai::ModelAgnosticService.new(
      provider: params[:provider],
      model: params[:model]
    )

    result = case @resource
             when Mention
               analyze_mention(service)
             when Lead
               analyze_lead(service)
             else
               { error: 'Unsupported resource type' }
             end

    respond_to do |format|
      format.json { render json: result }
      format.html { redirect_back(fallback_location: root_path, notice: 'Analysis completed') }
    end
  end

  def score
    scoring_service = Ai::MlScoringService.new(
      @resource,
      params[:model_type] || 'lead_scoring',
      threshold: params[:threshold]&.to_f || 0.5
    )

    result = scoring_service.perform

    respond_to do |format|
      format.json { render json: result }
      format.html do
        if result[:success]
          redirect_back(fallback_location: root_path, notice: "Scored: #{result[:score].round(2)} (#{result[:category]})")
        else
          redirect_back(fallback_location: root_path, alert: "Scoring failed: #{result[:error]}")
        end
      end
    end
  end

  def search
    index = SearchIndex.find_by(name: params[:index_name]) || SearchIndex.active.first
    
    return render json: { error: 'No active search index' } unless index

    results = index.search(
      params[:query],
      filters: search_filters,
      size: params[:limit] || 20,
      from: params[:offset] || 0
    )

    respond_to do |format|
      format.json { render json: results }
      format.html do
        @search_results = results
        render :search_results
      end
    end
  end

  def bulk_analyze
    mentions = current_user.mentions.includes(:analysis_result)
                          .where(analysis_result: { id: nil })
                          .limit(params[:batch_size] || 10)

    results = []
    service = Ai::ModelAgnosticService.new

    mentions.find_each do |mention|
      enhanced_service = Ai::EnhancedAnalysisService.new(mention, index: true)
      result = enhanced_service.perform
      results << {
        mention_id: mention.id,
        success: result[:success],
        sentiment: result[:sentiment],
        relevance_score: result[:relevance_score]
      }
    end

    render json: {
      processed: results.count,
      successful: results.count { |r| r[:success] },
      results: results
    }
  end

  def bulk_score
    leads = current_user.leads
                       .left_joins(:ml_scores)
                       .where(ml_scores: { id: nil })
                       .limit(params[:batch_size] || 10)

    results = []
    
    leads.find_each do |lead|
      scoring_service = Ai::MlScoringService.new(lead, 'lead_scoring')
      result = scoring_service.perform
      results << {
        lead_id: lead.id,
        success: result[:success],
        score: result[:score],
        category: result[:category]
      }
    end

    render json: {
      processed: results.count,
      successful: results.count { |r| r[:success] },
      results: results
    }
  end

  def configure_model
    ai_model = AiModel.find(params[:id])
    
    if ai_model.update(model_params)
      render json: { success: true, model: ai_model }
    else
      render json: { success: false, errors: ai_model.errors.full_messages }
    end
  end

  def test_provider
    service = Ai::ModelAgnosticService.new(
      provider: params[:provider],
      model: params[:model]
    )

    test_prompt = "Hello, this is a test. Please respond with 'Test successful'."
    result = service.complete(test_prompt)

    if result[:error]
      render json: { success: false, error: result[:message] }
    else
      render json: { 
        success: true, 
        response: result[:content],
        provider: result[:provider],
        model: result[:model]
      }
    end
  end

  def available_providers
    providers = Ai::ModelAgnosticService.available_providers.map do |provider|
      {
        name: provider,
        configured: Ai::ModelAgnosticService.provider_configured?(provider),
        models: available_models_for(provider)
      }
    end

    render json: providers
  end

  private

  def set_resource
    if params[:mention_id]
      @resource = current_user.mentions.find(params[:mention_id])
    elsif params[:lead_id]
      @resource = current_user.leads.find(params[:lead_id])
    elsif params[:analysis_id]
      @resource = AnalysisResult.joins(mention: :keyword)
                               .where(keywords: { user_id: current_user.id })
                               .find(params[:analysis_id])
    end
  end

  def analyze_mention(service)
    analysis_types = params[:analysis_types] || [:sentiment, :entities, :intent, :relevance]
    
    results = {}
    analysis_types.each do |type|
      results[type] = service.analyze_content(@resource.content, type)
    end

    # Save to database
    analysis = @resource.analysis_result || @resource.build_analysis_result
    analysis.update!(
      sentiment: results.dig(:sentiment, :sentiment) || 'neutral',
      entities: results.dig(:entities) || [],
      intent: results.dig(:intent, :primary_intent),
      relevance_score: results.dig(:relevance, :score) || 0.5,
      confidence_score: calculate_confidence(results),
      ai_model_used: service.provider,
      metadata: results
    )

    {
      success: true,
      analysis_id: analysis.id,
      results: results
    }
  end

  def analyze_lead(service)
    lead_data = {
      name: @resource.name,
      email: @resource.email,
      company: @resource.company,
      score: @resource.score,
      status: @resource.status,
      interaction_count: @resource.interaction_count,
      created_at: @resource.created_at
    }

    scoring_result = service.score_lead(lead_data)
    
    # Create ML score
    ml_score = @resource.ml_scores.create!(
      ml_model_name: "#{service.provider}_lead_scorer",
      score: scoring_result[:score],
      confidence: scoring_result[:confidence],
      features: { lead_data: lead_data },
      predictions: scoring_result,
      metadata: { provider: service.provider }
    )

    {
      success: true,
      score_id: ml_score.id,
      score: scoring_result[:score],
      confidence: scoring_result[:confidence],
      factors: scoring_result[:factors],
      recommendations: scoring_result[:recommendations]
    }
  end

  def calculate_confidence(results)
    confidences = results.values.map { |r| r[:confidence] if r.is_a?(Hash) }.compact
    return 0.5 if confidences.empty?
    confidences.sum.to_f / confidences.count
  end

  def search_filters
    filters = {}
    filters[:platform] = params[:platform] if params[:platform].present?
    filters[:sentiment] = params[:sentiment] if params[:sentiment].present?
    filters[:score] = params[:min_score]..1.0 if params[:min_score].present?
    filters[:created_at] = Date.parse(params[:from])..Date.parse(params[:to]) if params[:from].present? && params[:to].present?
    filters
  end

  def model_params
    params.require(:ai_model).permit(
      :name, :model_type, :provider, :version, :enabled, :priority,
      :description, configuration: {}, capabilities: [], pricing: {}
    )
  end

  def available_models_for(provider)
    case provider
    when 'openai'
      ['gpt-4-turbo-preview', 'gpt-4', 'gpt-3.5-turbo', 'text-embedding-3-small']
    when 'anthropic'
      ['claude-3-opus-20240229', 'claude-3-sonnet-20240229', 'claude-3-haiku-20240307']
    when 'google_gemini'
      ['gemini-pro', 'gemini-pro-vision']
    when 'cohere'
      ['command', 'command-light', 'embed-english-v3.0']
    when 'ollama'
      ['llama2', 'mistral', 'codellama', 'phi']
    else
      []
    end
  end
  end
end