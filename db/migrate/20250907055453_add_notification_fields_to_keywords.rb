class AddNotificationFieldsToKeywords < ActiveRecord::Migration[8.0]
  def change
    add_column :keywords, :priority, :string, default: 'medium'
    add_column :keywords, :notification_frequency, :string, default: 'daily'
  end
end
