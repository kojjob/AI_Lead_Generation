class CreateLeads < ActiveRecord::Migration[8.0]
  def change
    create_table :leads do |t|
      t.references :mention, null: false, foreign_key: true
      t.float :priority_score
      t.string :status
      t.string :lead_type, default: "lead"
      t.string :lead_source, default: "user"
      t.string :notes, default: ""  
      t.string :tags, array: true, default: []  
      t.datetime :last_contacted_at
      t.datetime :deleted_at
      t.string :search_status, default: "not_searched"
      t.string :search_type, default: "lead"
      t.string :search_source, default: "user"
      t.string :search_notes, default: ""
      t.string :search_tags, array: true, default: []  
      t.datetime :search_last_searched_at
      t.datetime :search_deleted_at

      t.timestamps
    end
  end
end
