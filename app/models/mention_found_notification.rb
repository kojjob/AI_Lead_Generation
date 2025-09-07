class MentionFoundNotification < Notification
  def message
    mention = Mention.find(params["mention_id"])
    "New mention found for keyword: #{mention.keyword.name}"
  rescue ActiveRecord::RecordNotFound
    "New mention found"
  end

  def url
    mention = Mention.find(params["mention_id"])
    Rails.application.routes.url_helpers.mention_path(mention)
  rescue ActiveRecord::RecordNotFound
    "#"
  end
end
