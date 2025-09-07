class LeadsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_lead, only: [ :show, :edit, :update, :destroy, :qualify, :contact, :convert ]
  before_action :ensure_user_owns_lead, only: [ :show, :edit, :update, :destroy, :qualify, :contact, :convert ]

  # GET /leads
  def index
    @leads = current_user.leads.includes(:mention, :keyword)

    # Apply filters
    @leads = apply_filters(@leads)

    # Apply search
    if params[:search].present?
      @leads = @leads.search(params[:search])
    end

    # Apply sorting
    @leads = apply_sorting(@leads)

    # Pagination - handle gracefully if Kaminari is not available
    begin
      @leads = @leads.page(params[:page]).per(25)
    rescue NoMethodError
      # Fallback to limit/offset if Kaminari is not working
      page = (params[:page] || 1).to_i
      per_page = 25
      offset = (page - 1) * per_page
      @leads = @leads.limit(per_page).offset(offset)
    end

    # Analytics for dashboard widgets
    @analytics = calculate_lead_analytics

    # Filter options for UI
    @filter_options = build_filter_options

    respond_to do |format|
      format.html
      format.json { render json: @leads }
      format.csv { send_csv_export }
    end
  end

  # GET /leads/1
  def show
    @interaction_history = build_interaction_history
    @related_leads = find_related_leads
    @conversion_timeline = build_conversion_timeline
  end

  # GET /leads/new
  def new
    @lead = Lead.new(user: current_user)
    @mentions = current_user.mentions.includes(:keyword).recent.limit(50)
  end

  # GET /leads/1/edit
  def edit
  end

  # POST /leads
  def create
    @lead = Lead.new(lead_params)
    @lead.user = current_user

    if @lead.save
      track_lead_creation
      redirect_to @lead, notice: "Lead was successfully created."
    else
      @mentions = current_user.mentions.includes(:keyword).recent.limit(50)
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /leads/1
  def update
    old_status = @lead.status

    if @lead.update(lead_params)
      track_lead_update(old_status)
      redirect_to @lead, notice: "Lead was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /leads/1
  def destroy
    @lead.destroy
    redirect_to leads_url, notice: "Lead was successfully deleted."
  end

  # Custom actions

  # POST /leads/1/qualify
  def qualify
    @lead.update(
      status: "qualified",
      lead_stage: "qualified",
      qualification_score: params[:score] || @lead.qualification_score
    )

    redirect_to @lead, notice: "Lead has been qualified."
  end

  # POST /leads/1/contact
  def contact
    @lead.update(
      status: "contacted",
      last_contacted_at: Time.current,
      contacted_by: current_user.name || current_user.email,
      contact_method: params[:method] || "email",
      next_follow_up: params[:follow_up_date]&.to_datetime
    )

    redirect_to @lead, notice: "Lead contact has been recorded."
  end

  # POST /leads/1/convert
  def convert
    @lead.update(
      status: "converted",
      lead_stage: "closed",
      conversion_value: params[:value],
      last_interaction_at: Time.current
    )

    redirect_to @lead, notice: "Lead has been converted! 🎉"
  end

  # POST /leads/bulk_action
  def bulk_action
    lead_ids = params[:lead_ids] || []
    action = params[:bulk_action]

    leads = current_user.leads.where(id: lead_ids)

    case action
    when "qualify"
      leads.update_all(status: "qualified", lead_stage: "qualified")
      message = "#{leads.count} leads qualified"
    when "contact"
      leads.update_all(status: "contacted", last_contacted_at: Time.current)
      message = "#{leads.count} leads marked as contacted"
    when "reject"
      leads.update_all(status: "rejected")
      message = "#{leads.count} leads rejected"
    when "archive"
      leads.update_all(status: "archived")
      message = "#{leads.count} leads archived"
    when "delete"
      count = leads.count
      leads.destroy_all
      message = "#{count} leads deleted"
    else
      message = "Invalid action"
    end

    redirect_to leads_path, notice: message
  end

  # GET /leads/analytics
  def analytics
    @analytics = detailed_lead_analytics
    @conversion_funnel = build_conversion_funnel
    @performance_metrics = calculate_performance_metrics

    respond_to do |format|
      format.html
      format.json { render json: @analytics }
    end
  end

  # GET /leads/export
  def export
    @leads = current_user.leads.includes(:mention, :keyword)
    @leads = apply_filters(@leads)

    respond_to do |format|
      format.csv { send_csv_export }
      format.pdf { send_pdf_export }
    end
  end

  private

  def set_lead
    @lead = current_user.leads.find(params[:id])
  end

  def ensure_user_owns_lead
    redirect_to leads_path, alert: "Lead not found." unless @lead
  end

  def lead_params
    params.require(:lead).permit(
      :mention_id, :name, :email, :phone, :company, :position,
      :status, :priority, :lead_stage, :temperature, :qualification_score,
      :notes, :contacted_by, :contact_method, :conversion_value,
      :next_follow_up, :source_platform, :source_url, :assigned_to,
      tags: []
    )
  end

  def apply_filters(leads)
    leads = leads.where(leads: { status: params[:status] }) if params[:status].present?
    leads = leads.where(leads: { priority: params[:priority] }) if params[:priority].present?
    leads = leads.where(leads: { lead_stage: params[:stage] }) if params[:stage].present?
    leads = leads.where(leads: { temperature: params[:temperature] }) if params[:temperature].present?
    leads = leads.where(leads: { source_platform: params[:platform] }) if params[:platform].present?
    leads = leads.where(leads: { assigned_to: params[:assigned_to] }) if params[:assigned_to].present?

    if params[:qualification_score].present?
      case params[:qualification_score]
      when "high" then leads = leads.where("leads.qualification_score >= ?", 70)
      when "medium" then leads = leads.where("leads.qualification_score BETWEEN ? AND ?", 40, 69)
      when "low" then leads = leads.where("leads.qualification_score < ?", 40)
      end
    end

    if params[:date_range].present?
      case params[:date_range]
      when "today" then leads = leads.where(created_at: Date.current.all_day)
      when "week" then leads = leads.where(created_at: 1.week.ago..Time.current)
      when "month" then leads = leads.where(created_at: 1.month.ago..Time.current)
      when "quarter" then leads = leads.where(created_at: 3.months.ago..Time.current)
      end
    end

    leads = leads.needs_follow_up if params[:needs_follow_up] == "true"

    leads
  end

  def apply_sorting(leads)
    case params[:sort]
    when "name" then leads.order(:name)
    when "email" then leads.order(:email)
    when "company" then leads.order(:company)
    when "status" then leads.order(:status)
    when "priority" then leads.by_priority
    when "score" then leads.order(qualification_score: :desc)
    when "created" then leads.order(created_at: :desc)
    when "updated" then leads.order(updated_at: :desc)
    when "follow_up" then leads.order(:next_follow_up)
    else leads.recent
    end
  end

  def calculate_lead_analytics
    leads = current_user.leads

    {
      total_leads: leads.count,
      new_leads: leads.new_leads.count,
      contacted_leads: leads.contacted.count,
      qualified_leads: leads.qualified.count,
      converted_leads: leads.converted.count,
      conversion_rate: calculate_conversion_rate(leads),
      avg_qualification_score: leads.average(:qualification_score)&.round(1) || 0,
      needs_follow_up: leads.needs_follow_up.count,
      hot_leads: leads.hot_leads.count,
      this_week: leads.where(created_at: 1.week.ago..Time.current).count,
      this_month: leads.where(created_at: 1.month.ago..Time.current).count
    }
  end

  def calculate_conversion_rate(leads)
    total = leads.where.not(status: "new").count
    return 0 if total.zero?

    converted = leads.converted.count
    ((converted.to_f / total) * 100).round(1)
  end

  def build_filter_options
    leads = current_user.leads

    {
      statuses: leads.distinct.pluck(:status).compact.sort,
      priorities: %w[low medium high urgent],
      stages: %w[prospect qualified opportunity proposal negotiation closed],
      temperatures: %w[cold warm hot],
      platforms: leads.distinct.pluck(:source_platform).compact.sort,
      assigned_users: leads.distinct.pluck(:assigned_to).compact.sort
    }
  end

  def build_interaction_history
    # This would integrate with a future interactions/activities model
    []
  end

  def find_related_leads
    return [] unless @lead.company.present? || @lead.email.present?

    current_user.leads.where.not(id: @lead.id)
                     .where("company = ? OR email = ?", @lead.company, @lead.email)
                     .limit(5)
  end

  def build_conversion_timeline
    # Timeline of lead progression through stages
    []
  end

  def track_lead_creation
    # Analytics tracking for lead creation
  end

  def track_lead_update(old_status)
    # Analytics tracking for lead updates
  end

  def send_csv_export
    csv_data = generate_csv_data(@leads)
    send_data csv_data, filename: "leads_export_#{Date.current}.csv", type: "text/csv"
  end

  def send_pdf_export
    # PDF export functionality would be implemented here
    redirect_to leads_path, alert: "PDF export coming soon!"
  end

  def generate_csv_data(leads)
    require "csv"

    CSV.generate(headers: true) do |csv|
      csv << [
        "Name", "Email", "Phone", "Company", "Position", "Status", "Priority",
        "Stage", "Temperature", "Qualification Score", "Source Platform",
        "Created At", "Last Contact", "Next Follow Up", "Conversion Value", "Notes"
      ]

      leads.each do |lead|
        csv << [
          lead.name, lead.email, lead.phone, lead.company, lead.position,
          lead.status, lead.priority, lead.lead_stage, lead.temperature,
          lead.qualification_score, lead.source_platform, lead.created_at,
          lead.last_contacted_at, lead.next_follow_up, lead.conversion_value,
          lead.notes
        ]
      end
    end
  end

  def detailed_lead_analytics
    # Detailed analytics for the analytics page
    calculate_lead_analytics
  end

  def build_conversion_funnel
    # Conversion funnel data
    {}
  end

  def calculate_performance_metrics
    # Performance metrics calculation
    {}
  end
end
