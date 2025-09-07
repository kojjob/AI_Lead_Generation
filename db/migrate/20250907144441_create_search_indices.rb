class CreateSearchIndices < ActiveRecord::Migration[8.0]
  def change
    create_table :search_indices do |t|
      t.string :name, null: false
      t.string :index_type, null: false
      t.jsonb :configuration, default: {}
      t.jsonb :mapping, default: {}
      t.string :status, default: 'pending'
      t.datetime :last_indexed_at
      t.datetime :last_synced_at
      t.integer :documents_count, default: 0
      t.jsonb :statistics, default: {}
      t.boolean :auto_sync, default: true
      t.integer :sync_frequency, default: 3600
      t.string :elasticsearch_index_name

      t.timestamps
    end

    add_index :search_indices, :name, unique: true
    add_index :search_indices, :index_type
    add_index :search_indices, :status
    add_index :search_indices, :auto_sync
  end
end
