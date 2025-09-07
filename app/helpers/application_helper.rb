module ApplicationHelper
  def notification_icon_gradient(notification)
    case notification.type
    when "LeadCreatedNotification"
      "bg-gradient-to-r from-green-400 to-emerald-500"
    when "MentionFoundNotification"
      "bg-gradient-to-r from-blue-400 to-indigo-500"
    when "AnalysisCompleteNotification"
      "bg-gradient-to-r from-purple-400 to-pink-500"
    else
      "bg-gradient-to-r from-gray-400 to-gray-500"
    end
  end

  def notification_icon_path(notification)
    case notification.type
    when "LeadCreatedNotification"
      "M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z"
    when "MentionFoundNotification"
      "M7 8h10M7 12h4m1 8l-4-4H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-3l-4 4z"
    when "AnalysisCompleteNotification"
      "M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"
    else
      "M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"
    end
  end
end
