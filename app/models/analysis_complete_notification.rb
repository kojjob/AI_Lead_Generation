class AnalysisCompleteNotification < Notification
  def message
    mention = Mention.find(params["mention_id"])
    "Analysis complete for mention from #{mention.source}"
  rescue ActiveRecord::RecordNotFound
    "Analysis complete"
  end
  
  def url
    mention = Mention.find(params["mention_id"])
    Rails.application.routes.url_helpers.mention_path(mention)
  rescue ActiveRecord::RecordNotFound
    "#"
  end
end