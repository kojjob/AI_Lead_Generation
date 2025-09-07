class AddPerformanceIndexes < ActiveRecord::Migration[8.0]
  def change
    # Indexes for foreign keys and frequently queried columns
    add_index :keywords, :user_id unless index_exists?(:keywords, :user_id)
    add_index :keywords, :status unless index_exists?(:keywords, :status)
    add_index :keywords, [:user_id, :status] unless index_exists?(:keywords, [:user_id, :status])
    
    add_index :mentions, :keyword_id unless index_exists?(:mentions, :keyword_id)
    add_index :mentions, :status unless index_exists?(:mentions, :status)
    add_index :mentions, :posted_at unless index_exists?(:mentions, :posted_at)
    add_index :mentions, [:keyword_id, :status] unless index_exists?(:mentions, [:keyword_id, :status])
    
    add_index :leads, :mention_id unless index_exists?(:leads, :mention_id)
    add_index :leads, :status unless index_exists?(:leads, :status)
    add_index :leads, :user_id unless index_exists?(:leads, :user_id)
    add_index :leads, [:user_id, :status] unless index_exists?(:leads, [:user_id, :status])
    
    add_index :analysis_results, :mention_id unless index_exists?(:analysis_results, :mention_id)
    add_index :analysis_results, :sentiment_score unless index_exists?(:analysis_results, :sentiment_score)
    
    add_index :integrations, :user_id unless index_exists?(:integrations, :user_id)
    add_index :integrations, :status unless index_exists?(:integrations, :status)
    add_index :integrations, :platform_name unless index_exists?(:integrations, :platform_name)
    
    add_index :notifications, :user_id unless index_exists?(:notifications, :user_id)
    add_index :notifications, :read_at unless index_exists?(:notifications, :read_at)
    add_index :notifications, [:user_id, :read_at] unless index_exists?(:notifications, [:user_id, :read_at])
  end
end
