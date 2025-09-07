class AddProfileFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    # Add only columns that don't exist
    add_column :users, :first_name, :string unless column_exists?(:users, :first_name)
    add_column :users, :last_name, :string unless column_exists?(:users, :last_name)
    add_column :users, :bio, :text unless column_exists?(:users, :bio)
    add_column :users, :job_title, :string unless column_exists?(:users, :job_title)
    add_column :users, :email_notifications, :boolean, default: true unless column_exists?(:users, :email_notifications)
    add_column :users, :sms_notifications, :boolean, default: false unless column_exists?(:users, :sms_notifications)
    add_column :users, :weekly_digest, :boolean, default: true unless column_exists?(:users, :weekly_digest)
    add_column :users, :marketing_emails, :boolean, default: false unless column_exists?(:users, :marketing_emails)
    add_column :users, :timezone, :string unless column_exists?(:users, :timezone)
    add_column :users, :language, :string unless column_exists?(:users, :language)
    # Note: phone and company already exist in the schema
  end
end
