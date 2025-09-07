class IntegrationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_integration, only: [ :show, :edit, :update, :destroy, :connect, :disconnect, :sync, :logs ]

  def index
    @integrations = current_user.integrations.includes(:integration_logs)
    @health_summary = {
      total: @integrations.count,
      connected: @integrations.connected.count,
      errors: @integrations.with_errors.count,
      sync_needed: @integrations.needs_sync.count
    }
  end

  def show
    @recent_logs = @integration.integration_logs.recent.limit(20)
    @statistics = {
      mentions_count: @integration.mentions_count,
      leads_count: @integration.leads_count,
      sync_success_rate: @integration.sync_success_rate,
      health_score: @integration.health_score
    }
  end

  def new
    @integration = current_user.integrations.build
    @available_platforms = Integration::SUPPORTED_PLATFORMS - current_user.integrations.pluck(:platform_name)
  end

  def create
    @integration = current_user.integrations.build(integration_params)

    if @integration.save
      @integration.connect! if params[:connect_immediately] == "1"
      redirect_to integrations_path, notice: "Integration was successfully created."
    else
      @available_platforms = Integration::SUPPORTED_PLATFORMS - current_user.integrations.pluck(:platform_name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @available_platforms = Integration::SUPPORTED_PLATFORMS
  end

  def update
    if @integration.update(integration_params)
      redirect_to integration_path(@integration), notice: "Integration was successfully updated."
    else
      @available_platforms = Integration::SUPPORTED_PLATFORMS
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @integration.disconnect!
    @integration.destroy
    redirect_to integrations_path, notice: "Integration was successfully removed."
  end

  # Custom actions
  def connect
    if @integration.connect!
      redirect_to integration_path(@integration), notice: "Successfully connected to platform."
    else
      redirect_to integration_path(@integration), alert: "Connection failed: #{@integration.error_message}"
    end
  end

  def disconnect
    @integration.disconnect!
    redirect_to integration_path(@integration), notice: "Successfully disconnected from platform."
  end

  def sync
    if @integration.sync!
      redirect_to integration_path(@integration), notice: "Sync initiated successfully."
    else
      redirect_to integration_path(@integration), alert: "Sync failed: #{@integration.error_message}"
    end
  end

  def logs
    @logs = @integration.integration_logs.recent.page(params[:page]).per(50)
    respond_to do |format|
      format.html
      format.json { render json: @logs }
    end
  end

  def health_check
    @integrations = current_user.integrations.includes(:integration_logs)
    @health_data = @integrations.map do |integration|
      {
        id: integration.id,
        platform: integration.platform_name,
        provider: integration.provider,
        status: integration.connection_status,
        health_score: integration.health_score,
        health_status: integration.health_status,
        last_sync: integration.last_sync_at,
        sync_status: integration.sync_status,
        error_count: integration.error_count
      }
    end

    respond_to do |format|
      format.html { render :health_check }
      format.json { render json: @health_data }
    end
  end

  private

  def set_integration
    @integration = current_user.integrations.find(params[:id])
  end

  def integration_params
    params.require(:integration).permit(
      :provider, :platform_name, :api_key, :api_secret,
      :access_token, :refresh_token, :sync_frequency,
      :enabled, :webhook_url, :webhook_secret,
      settings: {}
    )
  end
end
