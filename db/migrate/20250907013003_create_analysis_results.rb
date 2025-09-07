class CreateAnalysisResults < ActiveRecord::Migration[8.0]
  def change
    create_table :analysis_results do |t|
      t.references :mention, null: false, foreign_key: true
      t.float :sentiment_score
      t.jsonb :entities
      t.string :classification
      t.string :status, default: "active"
      t.string :type, default: "analysis_result"
      t.string :source, default: "user"
      t.string :notes, default: ""
      t.string :tags, array: true, default: []  
      t.datetime :last_searched_at
      t.datetime :deleted_at
      t.string :search_status, default: "not_searched"
      t.string :search_type, default: "analysis_result"
      t.string :search_source, default: "user"
      t.string :search_notes, default: ""
      t.string :search_tags, array: true, default: []  
      t.datetime :search_last_searched_at
      t.datetime :search_deleted_at

      t.timestamps
    end
  end
end
