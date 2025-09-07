class AddPlatformToMentions < ActiveRecord::Migration[8.0]
  def change
    add_column :mentions, :platform, :string
  end
end
