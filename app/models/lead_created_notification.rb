class LeadCreatedNotification < Notification
  def message
    lead = Lead.find(params["lead_id"])
    "New lead created: #{lead.company_name}"
  rescue ActiveRecord::RecordNotFound
    "New lead created"
  end

  def url
    lead = Lead.find(params["lead_id"])
    Rails.application.routes.url_helpers.lead_path(lead)
  rescue ActiveRecord::RecordNotFound
    "#"
  end
end
