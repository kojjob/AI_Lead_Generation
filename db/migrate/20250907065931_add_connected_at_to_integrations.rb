class AddConnectedAtToIntegrations < ActiveRecord::Migration[8.0]
  def change
    add_column :integrations, :connected_at, :datetime
  end
end
