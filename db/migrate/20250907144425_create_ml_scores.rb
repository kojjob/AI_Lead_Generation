class CreateMlScores < ActiveRecord::Migration[8.0]
  def change
    create_table :ml_scores do |t|
      t.references :scoreable, polymorphic: true, null: false
      t.string :ml_model_name, null: false
      t.float :score, null: false
      t.float :confidence
      t.jsonb :features, default: {}
      t.jsonb :predictions, default: {}
      t.jsonb :metadata, default: {}
      t.bigint :ai_model_id

      t.timestamps
    end

    add_index :ml_scores, :ml_model_name
    add_index :ml_scores, :score
    add_index :ml_scores, :ai_model_id
    add_index :ml_scores, [ :scoreable_type, :scoreable_id, :ml_model_name ],
              unique: true, name: 'idx_ml_scores_unique_model_per_scoreable'
    add_index :ml_scores, :created_at
  end
end
