class CreateAiModels < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_models do |t|
      t.string :name, null: false
      t.string :model_type, null: false
      t.string :provider, null: false
      t.string :version
      t.jsonb :configuration, default: {}
      t.jsonb :performance_metrics, default: {}
      t.boolean :enabled, default: true
      t.text :description
      t.jsonb :capabilities, default: {}
      t.jsonb :pricing, default: {}
      t.integer :priority, default: 0
      t.integer :usage_count, default: 0
      t.datetime :last_used_at

      t.timestamps
    end

    add_index :ai_models, :enabled
    add_index :ai_models, :model_type
    add_index :ai_models, :provider
    add_index :ai_models, [ :name, :provider ], unique: true
    add_index :ai_models, :priority
  end
end
