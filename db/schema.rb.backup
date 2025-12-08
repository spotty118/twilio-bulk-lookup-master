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

ActiveRecord::Schema[7.2].define(version: 2025_10_01_213225) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_admin_comments", force: :cascade do |t|
    t.string "namespace"
    t.text "body"
    t.string "resource_type"
    t.bigint "resource_id"
    t.string "author_type"
    t.bigint "author_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_type", "author_id"], name: "index_active_admin_comments_on_author"
    t.index ["namespace"], name: "index_active_admin_comments_on_namespace"
    t.index ["resource_type", "resource_id"], name: "index_active_admin_comments_on_resource"
  end

  create_table "admin_users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at", precision: nil
    t.datetime "remember_created_at", precision: nil
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at", precision: nil
    t.datetime "last_sign_in_at", precision: nil
    t.inet "current_sign_in_ip"
    t.inet "last_sign_in_ip"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["email"], name: "index_admin_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admin_users_on_reset_password_token", unique: true
  end

  create_table "contacts", force: :cascade do |t|
    t.string "raw_phone_number", null: false
    t.string "formatted_phone_number"
    t.string "mobile_network_code"
    t.string "error_code"
    t.string "mobile_country_code"
    t.string "carrier_name"
    t.string "device_type"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "status", default: "pending", null: false
    t.datetime "lookup_performed_at"
    t.index ["carrier_name", "device_type"], name: "index_contacts_on_carrier_and_device_where_completed", where: "((status)::text = 'completed'::text)"
    t.index ["created_at"], name: "index_contacts_on_created_at_where_pending", where: "((status)::text = 'pending'::text)"
    t.index ["error_code"], name: "index_contacts_on_error_code"
    t.index ["formatted_phone_number"], name: "index_contacts_on_formatted_phone_number"
    t.index ["lookup_performed_at"], name: "index_contacts_on_lookup_performed_at"
    t.index ["status", "lookup_performed_at"], name: "index_contacts_on_status_and_lookup_performed_at"
    t.index ["status"], name: "index_contacts_on_status"
    t.index ["updated_at"], name: "index_contacts_on_updated_at_where_failed", where: "((status)::text = 'failed'::text)"
  end

  create_table "twilio_credentials", force: :cascade do |t|
    t.string "account_sid"
    t.string "auth_token"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end
end
