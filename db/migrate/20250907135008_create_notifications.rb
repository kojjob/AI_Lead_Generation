class CreateNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.string :type
      t.text :params
      t.datetime :read_at

      t.timestamps
    end
  end
end
