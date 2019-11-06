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

ActiveRecord::Schema.define(version: 2019_03_25_000336) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "better_together_community_identifications", force: :cascade do |t|
    t.boolean "active", null: false
    t.string "identity_type", null: false
    t.bigint "identity_id", null: false
    t.string "agent_type", null: false
    t.bigint "agent_id", null: false
    t.string "bt_id", limit: 100, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active", "agent_type", "agent_id"], name: "active_identification", unique: true
    t.index ["active"], name: "by_active_state"
    t.index ["agent_type", "agent_id"], name: "by_agent"
    t.index ["bt_id"], name: "identification_by_bt_id", unique: true
    t.index ["identity_type", "identity_id", "agent_type", "agent_id"], name: "unique_identification", unique: true
    t.index ["identity_type", "identity_id"], name: "by_identity"
  end

  create_table "better_together_community_invitations", force: :cascade do |t|
    t.string "bt_id", limit: 100, null: false
    t.string "status", limit: 20, null: false
    t.datetime "valid_from", null: false
    t.datetime "valid_until"
    t.string "invitable_type", null: false
    t.bigint "invitable_id", null: false
    t.string "inviter_type", null: false
    t.bigint "inviter_id", null: false
    t.string "invitee_type", null: false
    t.bigint "invitee_id", null: false
    t.bigint "role_id"
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bt_id"], name: "invitation_by_bt_id", unique: true
    t.index ["invitable_type", "invitable_id"], name: "by_invitable"
    t.index ["invitee_type", "invitee_id"], name: "by_invitee"
    t.index ["inviter_type", "inviter_id"], name: "by_inviter"
    t.index ["role_id"], name: "by_role"
    t.index ["status"], name: "by_status"
    t.index ["valid_from"], name: "by_valid_from"
    t.index ["valid_until"], name: "by_valid_until"
  end

  create_table "better_together_community_people", force: :cascade do |t|
    t.string "given_name", limit: 50, null: false
    t.string "family_name", limit: 50
    t.string "bt_id", limit: 100, null: false
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bt_id"], name: "person_by_bt_id", unique: true
    t.index ["family_name"], name: "by_family_name"
    t.index ["given_name"], name: "by_given_name"
  end

  create_table "better_together_community_roles", force: :cascade do |t|
    t.string "bt_id", limit: 20, null: false
    t.boolean "reserved", default: false, null: false
    t.integer "sort_order"
    t.string "target_class", limit: 100
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bt_id"], name: "role_by_bt_id", unique: true
    t.index ["reserved"], name: "by_reserved_state"
    t.index ["sort_order"], name: "by_sort_order"
    t.index ["target_class"], name: "by_target_class"
  end

  create_table "friendly_id_slugs", force: :cascade do |t|
    t.string "slug", null: false
    t.integer "sluggable_id", null: false
    t.string "sluggable_type", limit: 50
    t.string "scope"
    t.datetime "created_at"
    t.index ["slug", "sluggable_type", "scope"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope", unique: true
    t.index ["slug", "sluggable_type"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type"
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

end
