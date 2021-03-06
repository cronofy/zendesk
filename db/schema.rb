# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20161030132531) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "delayed_jobs", force: :cascade do |t|
    t.integer  "priority",   default: 0, null: false
    t.integer  "attempts",   default: 0, null: false
    t.text     "handler",                null: false
    t.text     "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string   "locked_by"
    t.string   "queue"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "delayed_jobs", ["priority", "run_at"], name: "delayed_jobs_priority", using: :btree

  create_table "event_trackers", force: :cascade do |t|
    t.integer  "user_id"
    t.string   "event_id"
    t.integer  "operation"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "event_trackers", ["updated_at"], name: "index_event_trackers_on_updated_at", using: :btree
  add_index "event_trackers", ["user_id", "event_id"], name: "event_trackers_user_event_id", unique: true, using: :btree

  create_table "users", force: :cascade do |t|
    t.string   "email"
    t.string   "cronofy_id"
    t.string   "cronofy_access_token"
    t.string   "cronofy_refresh_token"
    t.datetime "created_at",                                      null: false
    t.datetime "updated_at",                                      null: false
    t.string   "zendesk_user_id"
    t.string   "zendesk_access_token"
    t.string   "cronofy_calendar_id"
    t.datetime "cronofy_access_token_expiration"
    t.datetime "cronofy_last_modified"
    t.datetime "zendesk_last_modified"
    t.text     "zendesk_subdomain"
    t.string   "zendesk_time_zone"
    t.string   "name"
    t.datetime "zendesk_sync_lock"
    t.boolean  "is_admin"
    t.boolean  "debug_enabled",                   default: false
  end

end
