class CreateIntegrations < ActiveRecord::Migration[8.0]
  def change
    create_table :integrations do |t|
      t.references :user, null: false, foreign_key: true
      t.string :provider
      t.jsonb :credentials
      t.string :status, default: "active"
      t.string :type, default: "integration"
      t.string :source, default: "user"
      t.string :notes, default: ""
      t.string :tags, array: true, default: []
      t.datetime :last_searched_at
      t.datetime :deleted_at
      t.string :search_status, default: "not_searched"
      t.string :search_type, default: "integration"
      t.string :search_source, default: "user"
      t.string :search_notes, default: ""
      t.string :search_tags, array: true, default: []
      t.datetime :search_last_searched_at
      t.datetime :search_deleted_at

      t.timestamps
    end
  end
end
