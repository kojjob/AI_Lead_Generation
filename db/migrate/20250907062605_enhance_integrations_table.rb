class EnhanceIntegrationsTable < ActiveRecord::Migration[8.0]
  def change
    # Add new columns for comprehensive integration support
    add_column :integrations, :platform_name, :string unless column_exists?(:integrations, :platform_name)
    add_column :integrations, :api_key, :text unless column_exists?(:integrations, :api_key)
    add_column :integrations, :api_secret, :text unless column_exists?(:integrations, :api_secret)
    add_column :integrations, :access_token, :text unless column_exists?(:integrations, :access_token)
    add_column :integrations, :refresh_token, :text unless column_exists?(:integrations, :refresh_token)
    add_column :integrations, :token_expires_at, :datetime unless column_exists?(:integrations, :token_expires_at)
    add_column :integrations, :last_sync_at, :datetime unless column_exists?(:integrations, :last_sync_at)
    add_column :integrations, :sync_frequency, :string, default: 'hourly' unless column_exists?(:integrations, :sync_frequency)
    add_column :integrations, :error_message, :text unless column_exists?(:integrations, :error_message)
    add_column :integrations, :error_count, :integer, default: 0 unless column_exists?(:integrations, :error_count)
    add_column :integrations, :last_error_at, :datetime unless column_exists?(:integrations, :last_error_at)
    add_column :integrations, :settings, :jsonb, default: {} unless column_exists?(:integrations, :settings)
    add_column :integrations, :enabled, :boolean, default: true unless column_exists?(:integrations, :enabled)
    add_column :integrations, :webhook_url, :string unless column_exists?(:integrations, :webhook_url)
    add_column :integrations, :webhook_secret, :string unless column_exists?(:integrations, :webhook_secret)
    add_column :integrations, :rate_limit_remaining, :integer unless column_exists?(:integrations, :rate_limit_remaining)
    add_column :integrations, :rate_limit_reset_at, :datetime unless column_exists?(:integrations, :rate_limit_reset_at)
    add_column :integrations, :sync_cursor, :string unless column_exists?(:integrations, :sync_cursor)
    add_column :integrations, :total_synced_items, :integer, default: 0 unless column_exists?(:integrations, :total_synced_items)
    add_column :integrations, :last_successful_sync_at, :datetime unless column_exists?(:integrations, :last_successful_sync_at)
    add_column :integrations, :connection_status, :string, default: 'disconnected' unless column_exists?(:integrations, :connection_status)
    add_column :integrations, :api_version, :string unless column_exists?(:integrations, :api_version)
    add_column :integrations, :metadata, :jsonb, default: {} unless column_exists?(:integrations, :metadata)

    # Add indexes for performance optimization
    add_index :integrations, [:user_id, :provider, :enabled], name: 'idx_integrations_user_provider_enabled' unless index_exists?(:integrations, [:user_id, :provider, :enabled])
    add_index :integrations, :platform_name unless index_exists?(:integrations, :platform_name)
    add_index :integrations, :connection_status unless index_exists?(:integrations, :connection_status)
    add_index :integrations, :last_sync_at unless index_exists?(:integrations, :last_sync_at)
    add_index :integrations, :enabled unless index_exists?(:integrations, :enabled)
    add_index :integrations, [:user_id, :connection_status], name: 'idx_integrations_user_connection' unless index_exists?(:integrations, [:user_id, :connection_status])
  end
end
