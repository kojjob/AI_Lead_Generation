# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_09_07_065931) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "analysis_results", force: :cascade do |t|
    t.bigint "mention_id", null: false
    t.float "sentiment_score"
    t.jsonb "entities"
    t.string "classification"
    t.string "status", default: "active"
    t.string "type", default: "analysis_result"
    t.string "source", default: "user"
    t.string "notes", default: ""
    t.string "tags", default: [], array: true
    t.datetime "last_searched_at"
    t.datetime "deleted_at"
    t.string "search_status", default: "not_searched"
    t.string "search_type", default: "analysis_result"
    t.string "search_source", default: "user"
    t.string "search_notes", default: ""
    t.string "search_tags", default: [], array: true
    t.datetime "search_last_searched_at"
    t.datetime "search_deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["mention_id"], name: "index_analysis_results_on_mention_id"
  end

  create_table "integration_logs", force: :cascade do |t|
    t.bigint "integration_id", null: false
    t.string "activity_type"
    t.text "details"
    t.datetime "performed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["integration_id"], name: "index_integration_logs_on_integration_id"
  end

  create_table "integrations", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "provider"
    t.jsonb "credentials"
    t.string "status", default: "active"
    t.string "type", default: "integration"
    t.string "source", default: "user"
    t.string "notes", default: ""
    t.string "tags", default: [], array: true
    t.datetime "last_searched_at"
    t.datetime "deleted_at"
    t.string "search_status", default: "not_searched"
    t.string "search_type", default: "integration"
    t.string "search_source", default: "user"
    t.string "search_notes", default: ""
    t.string "search_tags", default: [], array: true
    t.datetime "search_last_searched_at"
    t.datetime "search_deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "platform_name"
    t.text "api_key"
    t.text "api_secret"
    t.text "access_token"
    t.text "refresh_token"
    t.datetime "token_expires_at"
    t.datetime "last_sync_at"
    t.string "sync_frequency", default: "hourly"
    t.text "error_message"
    t.integer "error_count", default: 0
    t.datetime "last_error_at"
    t.jsonb "settings", default: {}
    t.boolean "enabled", default: true
    t.string "webhook_url"
    t.string "webhook_secret"
    t.integer "rate_limit_remaining"
    t.datetime "rate_limit_reset_at"
    t.string "sync_cursor"
    t.integer "total_synced_items", default: 0
    t.datetime "last_successful_sync_at"
    t.string "connection_status", default: "disconnected"
    t.string "api_version"
    t.jsonb "metadata", default: {}
    t.datetime "connected_at"
    t.index ["connection_status"], name: "index_integrations_on_connection_status"
    t.index ["enabled"], name: "index_integrations_on_enabled"
    t.index ["last_sync_at"], name: "index_integrations_on_last_sync_at"
    t.index ["platform_name"], name: "index_integrations_on_platform_name"
    t.index ["user_id", "connection_status"], name: "idx_integrations_user_connection"
    t.index ["user_id", "provider", "enabled"], name: "idx_integrations_user_provider_enabled"
    t.index ["user_id"], name: "index_integrations_on_user_id"
  end

  create_table "keywords", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "keyword"
    t.string "platform"
    t.boolean "active"
    t.string "status", default: "active"
    t.string "type", default: "keyword"
    t.string "source", default: "user"
    t.string "notes", default: ""
    t.string "tags", default: [], array: true
    t.datetime "last_searched_at"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "platforms"
    t.jsonb "search_parameters"
    t.string "priority", default: "medium"
    t.string "notification_frequency", default: "daily"
    t.index ["user_id"], name: "index_keywords_on_user_id"
  end

  create_table "leads", force: :cascade do |t|
    t.bigint "mention_id"
    t.float "priority_score"
    t.string "status"
    t.string "lead_type", default: "lead"
    t.string "lead_source", default: "user"
    t.string "notes", default: ""
    t.string "tags", default: [], array: true
    t.datetime "last_contacted_at"
    t.datetime "deleted_at"
    t.string "search_status", default: "not_searched"
    t.string "search_type", default: "lead"
    t.string "search_source", default: "user"
    t.string "search_notes", default: ""
    t.string "search_tags", default: [], array: true
    t.datetime "search_last_searched_at"
    t.datetime "search_deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.string "email"
    t.string "phone"
    t.string "company"
    t.string "position"
    t.integer "qualification_score", default: 0
    t.string "priority", default: "medium"
    t.string "contacted_by"
    t.string "contact_method"
    t.decimal "conversion_value", precision: 10, scale: 2
    t.datetime "next_follow_up"
    t.string "lead_stage", default: "prospect"
    t.string "source_platform"
    t.text "source_url"
    t.integer "interaction_count", default: 0
    t.datetime "last_interaction_at"
    t.string "assigned_to"
    t.string "temperature", default: "cold"
    t.bigint "user_id", null: false
    t.index ["created_at"], name: "index_leads_on_created_at"
    t.index ["email"], name: "index_leads_on_email"
    t.index ["lead_stage"], name: "index_leads_on_lead_stage"
    t.index ["mention_id"], name: "index_leads_on_mention_id"
    t.index ["priority"], name: "index_leads_on_priority"
    t.index ["qualification_score"], name: "index_leads_on_qualification_score"
    t.index ["status"], name: "index_leads_on_status"
    t.index ["user_id"], name: "index_leads_on_user_id"
  end

  create_table "mentions", force: :cascade do |t|
    t.bigint "keyword_id", null: false
    t.jsonb "raw_payload"
    t.text "content"
    t.string "author"
    t.datetime "posted_at"
    t.string "status", default: "active"
    t.string "type", default: "mention"
    t.string "source", default: "user"
    t.string "notes", default: ""
    t.string "tags", default: [], array: true
    t.datetime "last_searched_at"
    t.datetime "deleted_at"
    t.string "search_status", default: "not_searched"
    t.string "search_type", default: "mention"
    t.string "search_source", default: "user"
    t.string "search_notes", default: ""
    t.string "search_tags", default: [], array: true
    t.datetime "search_last_searched_at"
    t.datetime "search_deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "platform"
    t.index ["keyword_id"], name: "index_mentions_on_keyword_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "name"
    t.string "phone"
    t.string "company"
    t.string "title"
    t.string "website"
    t.string "role", default: "user"
    t.jsonb "preferences", default: []
    t.boolean "terms_of_service", default: false, null: false
    t.boolean "privacy_policy", default: false, null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "first_name"
    t.string "last_name"
    t.text "bio"
    t.string "job_title"
    t.boolean "email_notifications", default: true
    t.boolean "sms_notifications", default: false
    t.boolean "weekly_digest", default: true
    t.boolean "marketing_emails", default: false
    t.string "timezone"
    t.string "language"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "analysis_results", "mentions"
  add_foreign_key "integration_logs", "integrations"
  add_foreign_key "integrations", "users"
  add_foreign_key "keywords", "users"
  add_foreign_key "leads", "mentions"
  add_foreign_key "leads", "users"
  add_foreign_key "mentions", "keywords"
end
