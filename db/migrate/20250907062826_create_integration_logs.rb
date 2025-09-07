class CreateIntegrationLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :integration_logs do |t|
      t.references :integration, null: false, foreign_key: true
      t.string :activity_type
      t.text :details
      t.datetime :performed_at

      t.timestamps
    end
  end
end
