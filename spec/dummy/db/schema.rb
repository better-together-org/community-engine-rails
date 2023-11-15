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

ActiveRecord::Schema[7.0].define(version: 2021_01_03_201642) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "better_together_communities", primary_key: "bt_id", id: :uuid, default: nil, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name", limit: 191
    t.text "description"
    t.uuid "creator_id", null: false
    t.string "privacy", limit: 50, default: "public", null: false
    t.index ["bt_id"], name: "community_by_bt_id", unique: true
    t.index ["creator_id"], name: "by_creator"
    t.index ["description"], name: "by_community_description"
    t.index ["name"], name: "by_community_name"
    t.index ["privacy"], name: "by_community_privacy"
  end

  create_table "better_together_identifications", primary_key: "bt_id", id: :uuid, default: nil, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "active", null: false
    t.string "identity_type", null: false
    t.bigint "identity_id", null: false
    t.string "agent_type", null: false
    t.bigint "agent_id", null: false
    t.index ["active", "agent_type", "agent_id"], name: "active_identification", unique: true
    t.index ["active"], name: "by_active_state"
    t.index ["agent_type", "agent_id"], name: "by_agent"
    t.index ["bt_id"], name: "identification_by_bt_id", unique: true
    t.index ["identity_type", "identity_id", "agent_type", "agent_id"], name: "unique_identification", unique: true
    t.index ["identity_type", "identity_id"], name: "by_identity"
  end

  create_table "better_together_jwt_denylists", primary_key: "bt_id", id: :uuid, default: nil, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "jti"
    t.datetime "exp"
    t.index ["bt_id"], name: "jwt_denylist_by_bt_id", unique: true
    t.index ["jti"], name: "index_better_together_jwt_denylists_on_jti"
  end

  create_table "better_together_people", primary_key: "bt_id", id: :uuid, default: nil, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name", limit: 191
    t.text "description"
    t.index ["bt_id"], name: "person_by_bt_id", unique: true
    t.index ["name"], name: "by_name"
  end

  create_table "better_together_person_community_memberships", primary_key: "bt_id", id: :uuid, default: nil, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "member_id", null: false
    t.uuid "community_id", null: false
    t.uuid "role_id", null: false
    t.index ["bt_id"], name: "person_community_membership_by_bt_id", unique: true
    t.index ["community_id", "member_id", "role_id"], name: "unique_person_community_membership_member_role", unique: true
    t.index ["community_id"], name: "person_community_membership_by_community"
    t.index ["member_id"], name: "person_community_membership_by_member"
    t.index ["role_id"], name: "person_community_membership_by_role"
  end

  create_table "better_together_roles", primary_key: "bt_id", id: :uuid, default: nil, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "reserved", default: false, null: false
    t.integer "sort_order"
    t.string "target_class", limit: 100
    t.index ["bt_id"], name: "role_by_bt_id", unique: true
    t.index ["reserved"], name: "by_reserved_state"
    t.index ["target_class", "sort_order"], name: "index_roles_on_target_class_and_sort_order", unique: true
  end

  create_table "better_together_users", primary_key: "bt_id", id: :uuid, default: nil, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at"
    t.index ["bt_id"], name: "user_by_bt_id", unique: true
    t.index ["confirmation_token"], name: "index_better_together_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_better_together_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_better_together_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_better_together_users_on_unlock_token", unique: true
  end

  create_table "friendly_id_slugs", force: :cascade do |t|
    t.string "slug", null: false
    t.integer "sluggable_id", null: false
    t.string "sluggable_type", limit: 50
    t.string "scope"
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "locale"
    t.index ["locale"], name: "index_friendly_id_slugs_on_locale"
    t.index ["slug", "sluggable_type", "locale"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type_and_locale"
    t.index ["slug", "sluggable_type", "scope", "locale"], name: "index_friendly_id_slugs_unique", unique: true
    t.index ["sluggable_type", "sluggable_id"], name: "index_friendly_id_slugs_on_sluggable_type_and_sluggable_id"
  end

  create_table "mobility_string_translations", force: :cascade do |t|
    t.string "locale", null: false
    t.string "key", null: false
    t.string "value"
    t.string "translatable_type"
    t.bigint "translatable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["translatable_id", "translatable_type", "key"], name: "index_mobility_string_translations_on_translatable_attribute"
    t.index ["translatable_id", "translatable_type", "locale", "key"], name: "index_mobility_string_translations_on_keys", unique: true
    t.index ["translatable_type", "key", "value", "locale"], name: "index_mobility_string_translations_on_query_keys"
  end

  create_table "mobility_text_translations", force: :cascade do |t|
    t.string "locale", null: false
    t.string "key", null: false
    t.text "value"
    t.string "translatable_type"
    t.bigint "translatable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["translatable_id", "translatable_type", "key"], name: "index_mobility_text_translations_on_translatable_attribute"
    t.index ["translatable_id", "translatable_type", "locale", "key"], name: "index_mobility_text_translations_on_keys", unique: true
  end

  add_foreign_key "better_together_communities", "better_together_people", column: "creator_id", primary_key: "bt_id"
  add_foreign_key "better_together_person_community_memberships", "better_together_communities", column: "community_id", primary_key: "bt_id"
  add_foreign_key "better_together_person_community_memberships", "better_together_people", column: "member_id", primary_key: "bt_id"
  add_foreign_key "better_together_person_community_memberships", "better_together_roles", column: "role_id", primary_key: "bt_id"
end
