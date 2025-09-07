class KeywordsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_keyword, only: [ :show, :edit, :update, :destroy ]

  def index
    @keywords = current_user.keywords.includes(:mentions, :leads)
    @active_keywords = @keywords.active
    @total_mentions = current_user.keywords.joins(:mentions).count
    @total_leads = current_user.keywords.joins(:leads).count
  end

  def show
    @recent_mentions = @keyword.mentions.includes(:analysis_result, :lead).order(created_at: :desc).limit(10)
    @performance_data = {
      mentions_count: @keyword.mentions_count,
      leads_count: @keyword.leads_count,
      conversion_rate: @keyword.conversion_rate,
      performance_score: @keyword.performance_score
    }
  end

  def new
    @keyword = current_user.keywords.build
  end

  def create
    @keyword = current_user.keywords.build(keyword_params)

    if @keyword.save
      redirect_to @keyword, notice: "Keyword was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @keyword.update(keyword_params)
      redirect_to @keyword, notice: "Keyword was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @keyword.destroy
    redirect_to keywords_path, notice: "Keyword was successfully deleted."
  end

  private

  def set_keyword
    @keyword = current_user.keywords.find(params[:id])
  end

  def keyword_params
    permitted = params.require(:keyword).permit(
      :keyword, :type, :status, :active, :notes, :priority, :notification_frequency,
      :search_parameters, platforms: []
    )

    # Convert platforms array to comma-separated string for storage
    if permitted[:platforms].present?
      permitted[:platforms] = permitted[:platforms].reject(&:blank?).join(",")
    end

    # Set default values
    permitted[:active] = true if permitted[:active].nil?
    permitted[:status] = "active" if permitted[:status].blank?
    permitted[:type] = "standard" if permitted[:type].blank?
    permitted[:priority] = "medium" if permitted[:priority].blank?
    permitted[:notification_frequency] = "daily" if permitted[:notification_frequency].blank?

    permitted
  end
end
