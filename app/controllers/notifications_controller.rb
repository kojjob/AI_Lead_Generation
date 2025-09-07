class NotificationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_notification, only: [:mark_as_read]
  
  def index
    @notifications = current_user.notifications.includes(:user).order(created_at: :desc)
    @unread_notifications = @notifications.unread
    @read_notifications = @notifications.read
  end
  
  def mark_as_read
    @notification.read!
    
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(@notification, partial: "notifications/notification", locals: { notification: @notification }),
          turbo_stream.replace("notifications-count", partial: "shared/notifications_count", locals: { user: current_user })
        ]
      end
      format.html { redirect_back(fallback_location: notifications_path) }
    end
  end
  
  def mark_all_as_read
    current_user.notifications.unread.update_all(read_at: Time.current)
    
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("notifications-list", partial: "notifications/list", locals: { notifications: current_user.notifications }),
          turbo_stream.replace("notifications-count", partial: "shared/notifications_count", locals: { user: current_user })
        ]
      end
      format.html { redirect_back(fallback_location: notifications_path) }
    end
  end
  
  private
  
  def set_notification
    @notification = current_user.notifications.find(params[:id])
  end
end
