class CreateKeywords < ActiveRecord::Migration[8.0]
  def change
    create_table :keywords do |t|
      t.references :user, null: false, foreign_key: true
      t.string :keyword
      t.string :platform
      t.boolean :active
      t.string :status, default: "active"
      t.string :type, default: "keyword"
      t.string :source, default: "user"
      t.string :notes, default: ""
      t.string :tags, array: true, default: []
      t.datetime :last_searched_at
      t.datetime :deleted_at

      t.timestamps
    end
  end
end
