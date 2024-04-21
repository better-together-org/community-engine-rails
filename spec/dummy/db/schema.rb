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

ActiveRecord::Schema[7.0].define(version: 2024_04_21_005311) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pgcrypto"
  enable_extension "plpgsql"

  create_table "action_text_rich_texts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.uuid "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "locale", null: false
    t.index ["record_type", "record_id", "name", "locale"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.uuid "record_id", null: false
    t.uuid "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "better_together_communities", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "identifier", limit: 100, null: false
    t.boolean "protected", default: false, null: false
    t.string "slug", null: false
    t.uuid "creator_id"
    t.string "privacy", limit: 50, default: "public", null: false
    t.boolean "host", default: false, null: false
    t.index ["creator_id"], name: "by_creator"
    t.index ["host"], name: "index_better_together_communities_on_host", unique: true, where: "((host IS TRUE) AND (creator_id IS NULL))"
    t.index ["identifier"], name: "index_better_together_communities_on_identifier", unique: true
    t.index ["privacy"], name: "by_community_privacy"
    t.index ["slug"], name: "index_better_together_communities_on_slug", unique: true
  end

  create_table "better_together_identifications", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "active", null: false
    t.string "identity_type", null: false
    t.uuid "identity_id", null: false
    t.string "agent_type", null: false
    t.uuid "agent_id", null: false
    t.index ["active", "agent_type", "agent_id"], name: "active_identification", unique: true
    t.index ["active"], name: "by_active_state"
    t.index ["agent_type", "agent_id"], name: "by_agent"
    t.index ["identity_type", "identity_id", "agent_type", "agent_id"], name: "unique_identification", unique: true
    t.index ["identity_type", "identity_id"], name: "by_identity"
  end

  create_table "better_together_jwt_denylists", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "jti"
    t.datetime "exp"
    t.index ["jti"], name: "index_better_together_jwt_denylists_on_jti"
  end

  create_table "better_together_navigation_areas", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "identifier", limit: 100, null: false
    t.boolean "protected", default: false, null: false
    t.string "name", null: false
    t.string "style"
    t.boolean "visible", default: true, null: false
    t.string "slug", null: false
    t.string "navigable_type"
    t.bigint "navigable_id"
    t.index ["identifier"], name: "index_better_together_navigation_areas_on_identifier", unique: true
    t.index ["navigable_type", "navigable_id"], name: "by_navigable"
    t.index ["slug"], name: "index_better_together_navigation_areas_on_slug", unique: true
  end

  create_table "better_together_navigation_items", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "identifier", limit: 100, null: false
    t.uuid "navigation_area_id", null: false
    t.uuid "parent_id"
    t.boolean "protected", default: false, null: false
    t.string "slug", null: false
    t.string "url"
    t.string "icon"
    t.integer "position", null: false
    t.boolean "visible", default: true, null: false
    t.string "item_type", null: false
    t.string "linkable_type"
    t.uuid "linkable_id"
    t.index ["identifier"], name: "index_better_together_navigation_items_on_identifier", unique: true
    t.index ["linkable_type", "linkable_id"], name: "by_linkable"
    t.index ["navigation_area_id", "parent_id", "position"], name: "navigation_items_area_position", unique: true
    t.index ["navigation_area_id"], name: "index_better_together_navigation_items_on_navigation_area_id"
    t.index ["parent_id"], name: "by_nav_item_parent"
    t.index ["slug"], name: "index_better_together_navigation_items_on_slug", unique: true
  end

  create_table "better_together_pages", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "identifier", limit: 100, null: false
    t.boolean "protected", default: false, null: false
    t.string "slug", null: false
    t.text "meta_description"
    t.string "keywords"
    t.boolean "published"
    t.datetime "published_at"
    t.string "privacy", default: "public", null: false
    t.string "layout"
    t.string "template"
    t.string "language", default: "en"
    t.index ["identifier"], name: "index_better_together_pages_on_identifier", unique: true
    t.index ["privacy"], name: "by_page_privacy"
    t.index ["published"], name: "by_page_publication_status"
    t.index ["published_at"], name: "by_page_publication_date"
    t.index ["slug"], name: "index_better_together_pages_on_slug", unique: true
  end

  create_table "better_together_people", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "identifier", limit: 100, null: false
    t.string "slug", null: false
    t.index ["identifier"], name: "index_better_together_people_on_identifier", unique: true
    t.index ["slug"], name: "index_better_together_people_on_slug", unique: true
  end

  create_table "better_together_person_community_memberships", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "member_id", null: false
    t.uuid "community_id", null: false
    t.uuid "role_id", null: false
    t.index ["community_id", "member_id", "role_id"], name: "unique_person_community_membership_member_role", unique: true
    t.index ["community_id"], name: "person_community_membership_by_community"
    t.index ["member_id"], name: "person_community_membership_by_member"
    t.index ["role_id"], name: "person_community_membership_by_role"
  end

  create_table "better_together_platforms", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "identifier", limit: 100, null: false
    t.uuid "community_id"
    t.boolean "protected", default: false, null: false
    t.string "slug", null: false
    t.string "url", null: false
    t.boolean "host", default: false, null: false
    t.string "time_zone", null: false
    t.string "privacy", limit: 50, default: "public", null: false
    t.index ["community_id"], name: "by_platform_community"
    t.index ["host"], name: "index_better_together_platforms_on_host", unique: true, where: "(host IS TRUE)"
    t.index ["identifier"], name: "index_better_together_platforms_on_identifier", unique: true
    t.index ["privacy"], name: "by_platform_privacy"
    t.index ["slug"], name: "index_better_together_platforms_on_slug", unique: true
    t.index ["url"], name: "index_better_together_platforms_on_url", unique: true
  end

  create_table "better_together_resource_permissions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "identifier", limit: 100, null: false
    t.boolean "protected", default: false, null: false
    t.integer "position", null: false
    t.string "action", null: false
    t.string "resource_class", null: false
    t.string "slug", null: false
    t.index ["identifier"], name: "index_better_together_resource_permissions_on_identifier", unique: true
    t.index ["slug"], name: "index_better_together_resource_permissions_on_slug", unique: true
  end

  create_table "better_together_roles", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "identifier", limit: 100, null: false
    t.boolean "protected", default: false, null: false
    t.integer "position", null: false
    t.string "slug", null: false
    t.string "resource_class", null: false
    t.index ["identifier"], name: "index_better_together_roles_on_identifier", unique: true
    t.index ["resource_class", "position"], name: "index_roles_on_resource_class_and_position", unique: true
    t.index ["slug"], name: "index_better_together_roles_on_slug", unique: true
  end

  create_table "better_together_users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
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
    t.index ["confirmation_token"], name: "index_better_together_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_better_together_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_better_together_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_better_together_users_on_unlock_token", unique: true
  end

  create_table "better_together_wizard_step_definitions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "identifier", limit: 100, null: false
    t.uuid "wizard_id", null: false
    t.boolean "protected", default: false, null: false
    t.string "slug", null: false
    t.string "template"
    t.string "form_class"
    t.string "message", default: "Please complete this next step.", null: false
    t.integer "step_number", null: false
    t.index ["identifier"], name: "index_better_together_wizard_step_definitions_on_identifier", unique: true
    t.index ["slug"], name: "index_better_together_wizard_step_definitions_on_slug", unique: true
    t.index ["wizard_id", "step_number"], name: "index_wizard_step_definitions_on_wizard_id_and_step_number", unique: true
    t.index ["wizard_id"], name: "by_step_definition_wizard"
  end

  create_table "better_together_wizard_steps", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "wizard_id", null: false
    t.uuid "wizard_step_definition_id", null: false
    t.uuid "creator_id"
    t.string "identifier", limit: 100, null: false
    t.boolean "completed", default: false
    t.integer "step_number", null: false
    t.index ["creator_id"], name: "by_step_creator"
    t.index ["identifier"], name: "by_step_identifier"
    t.index ["wizard_id", "identifier", "creator_id"], name: "index_unique_wizard_steps", unique: true, where: "(completed IS FALSE)"
    t.index ["wizard_id", "step_number"], name: "index_wizard_steps_on_wizard_id_and_step_number"
    t.index ["wizard_id"], name: "by_step_wizard"
    t.index ["wizard_step_definition_id"], name: "by_step_wizard_step_definition"
  end

  create_table "better_together_wizards", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "identifier", limit: 100, null: false
    t.boolean "protected", default: false, null: false
    t.string "slug", null: false
    t.integer "max_completions", default: 0, null: false
    t.integer "current_completions", default: 0, null: false
    t.datetime "first_completed_at"
    t.datetime "last_completed_at"
    t.text "success_message", default: "Thank you. You have successfully completed the wizard", null: false
    t.string "success_path", default: "/", null: false
    t.index ["identifier"], name: "index_better_together_wizards_on_identifier", unique: true
    t.index ["slug"], name: "index_better_together_wizards_on_slug", unique: true
  end

  create_table "friendly_id_slugs", force: :cascade do |t|
    t.string "slug", null: false
    t.uuid "sluggable_id", null: false
    t.string "sluggable_type", null: false
    t.string "scope"
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "locale", null: false
    t.index ["locale"], name: "index_friendly_id_slugs_on_locale"
    t.index ["slug", "sluggable_type", "locale"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type_and_locale"
    t.index ["slug", "sluggable_type", "scope", "locale"], name: "index_friendly_id_slugs_unique", unique: true
    t.index ["sluggable_type", "sluggable_id"], name: "by_sluggable"
  end

  create_table "mobility_string_translations", force: :cascade do |t|
    t.string "locale", null: false
    t.string "key", null: false
    t.string "value"
    t.string "translatable_type"
    t.uuid "translatable_id"
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
    t.uuid "translatable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["translatable_id", "translatable_type", "key"], name: "index_mobility_text_translations_on_translatable_attribute"
    t.index ["translatable_id", "translatable_type", "locale", "key"], name: "index_mobility_text_translations_on_keys", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "better_together_communities", "better_together_people", column: "creator_id"
  add_foreign_key "better_together_navigation_items", "better_together_navigation_areas", column: "navigation_area_id"
  add_foreign_key "better_together_navigation_items", "better_together_navigation_items", column: "parent_id"
  add_foreign_key "better_together_person_community_memberships", "better_together_communities", column: "community_id"
  add_foreign_key "better_together_person_community_memberships", "better_together_people", column: "member_id"
  add_foreign_key "better_together_person_community_memberships", "better_together_roles", column: "role_id"
  add_foreign_key "better_together_platforms", "better_together_communities", column: "community_id"
  add_foreign_key "better_together_wizard_step_definitions", "better_together_wizards", column: "wizard_id"
  add_foreign_key "better_together_wizard_steps", "better_together_people", column: "creator_id"
  add_foreign_key "better_together_wizard_steps", "better_together_wizard_step_definitions", column: "wizard_step_definition_id"
  add_foreign_key "better_together_wizard_steps", "better_together_wizards", column: "wizard_id"
end
