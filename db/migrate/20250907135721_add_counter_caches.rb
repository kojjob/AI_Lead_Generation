class AddCounterCaches < ActiveRecord::Migration[8.0]
  def change
    # Add counter cache columns
    add_column :users, :keywords_count, :integer, default: 0, null: false
    add_column :users, :leads_count, :integer, default: 0, null: false
    add_column :users, :integrations_count, :integer, default: 0, null: false

    add_column :keywords, :mentions_count, :integer, default: 0, null: false
    add_column :keywords, :leads_count, :integer, default: 0, null: false

    # Reset counters for existing records
    reversible do |dir|
      dir.up do
        User.find_each do |user|
          User.reset_counters(user.id, :keywords, :leads, :integrations)
        end

        Keyword.find_each do |keyword|
          Keyword.reset_counters(keyword.id, :mentions)
        end
      end
    end
  end
end
