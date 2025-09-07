class CreateWebhooks < ActiveRecord::Migration[8.0]
  def change
    create_table :webhooks do |t|
      t.references :integration, null: false, foreign_key: true
      t.string :event_type, null: false
      t.text :payload, null: false
      t.string :status, default: 'pending', null: false
      t.datetime :processed_at
      t.text :error_message
      t.string :signature
      t.string :source_ip
      t.string :user_agent
      t.json :headers
      t.integer :retry_count, default: 0
      t.datetime :next_retry_at

      t.timestamps
    end

    add_index :webhooks, [ :integration_id, :event_type ]
    add_index :webhooks, [ :status, :created_at ]
    add_index :webhooks, :processed_at
    add_index :webhooks, :next_retry_at
  end
end
