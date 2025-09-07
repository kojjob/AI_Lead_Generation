class Notification < ApplicationRecord
  belongs_to :user

  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }

  serialize :params, coder: JSON

  after_create_commit -> { broadcast_notification }

  def read!
    update!(read_at: Time.current)
  end

  def unread?
    read_at.nil?
  end

  def to_partial_path
    "notifications/#{self.class.name.underscore}"
  end

  # Override in subclasses
  def message
    raise NotImplementedError
  end

  # Override in subclasses
  def url
    "#"
  end

  private

  def broadcast_notification
    broadcast_prepend_later_to(
      user,
      :notifications,
      target: "notifications-list",
      partial: "notifications/notification",
      locals: { notification: self }
    )

    broadcast_replace_later_to(
      user,
      :notifications_count,
      target: "notifications-count",
      partial: "shared/notifications_count",
      locals: { user: user }
    )
  end
end
