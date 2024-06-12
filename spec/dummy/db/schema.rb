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

ActiveRecord::Schema[7.1].define(version: 2025_08_22_143049) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pgcrypto"
  enable_extension "plpgsql"
  enable_extension "postgis"

  create_table "action_text_rich_texts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.uuid "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "locale"
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

  create_table "better_together_activities", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "trackable_type"
    t.uuid "trackable_id"
    t.string "owner_type"
    t.uuid "owner_id"
    t.string "key"
    t.jsonb "parameters", default: "{}"
    t.string "recipient_type"
    t.uuid "recipient_id"
    t.string "privacy", limit: 50, default: "private", null: false
    t.index ["owner_type", "owner_id"], name: "bt_activities_by_owner"
    t.index ["privacy"], name: "by_better_together_activities_privacy"
    t.index ["recipient_type", "recipient_id"], name: "bt_activities_by_recipient"
    t.index ["trackable_type", "trackable_id"], name: "bt_activities_by_trackable"
  end

  create_table "better_together_addresses", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "label", default: "main", null: false
    t.boolean "physical", default: true, null: false
    t.boolean "postal", default: false, null: false
    t.string "line1"
    t.string "line2"
    t.string "city_name"
    t.string "state_province_name"
    t.string "postal_code"
    t.string "country_name"
    t.string "privacy", limit: 50, default: "private", null: false
    t.uuid "contact_detail_id"
    t.boolean "primary_flag", default: false, null: false
    t.index ["contact_detail_id", "primary_flag"], name: "index_bt_addresses_on_contact_detail_id_and_primary", unique: true, where: "(primary_flag IS TRUE)"
    t.index ["contact_detail_id"], name: "index_better_together_addresses_on_contact_detail_id"
    t.index ["privacy"], name: "by_better_together_addresses_privacy"
  end

  create_table "better_together_agreement_participants", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "agreement_id", null: false
    t.uuid "person_id", null: false
    t.string "group_identifier"
    t.datetime "accepted_at"
    t.index ["agreement_id", "person_id"], name: "index_bt_agreement_participants_on_agreement_and_person", unique: true
    t.index ["agreement_id"], name: "index_better_together_agreement_participants_on_agreement_id"
    t.index ["group_identifier"], name: "idx_on_group_identifier_06b6e57c0b"
    t.index ["person_id"], name: "index_better_together_agreement_participants_on_person_id"
  end

  create_table "better_together_agreement_terms", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "identifier", limit: 100, null: false
    t.integer "position", null: false
    t.boolean "protected", default: false, null: false
    t.uuid "agreement_id", null: false
    t.index ["agreement_id"], name: "index_better_together_agreement_terms_on_agreement_id"
    t.index ["identifier"], name: "index_better_together_agreement_terms_on_identifier", unique: true
  end

  create_table "better_together_agreements", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "creator_id"
    t.string "identifier", limit: 100, null: false
    t.boolean "protected", default: false, null: false
    t.string "privacy", limit: 50, default: "private", null: false
    t.boolean "collective", default: false, null: false
    t.uuid "page_id"
    t.index ["creator_id"], name: "by_better_together_agreements_creator"
    t.index ["identifier"], name: "index_better_together_agreements_on_identifier", unique: true
    t.index ["page_id"], name: "index_better_together_agreements_on_page_id"
    t.index ["privacy"], name: "by_better_together_agreements_privacy"
  end

  create_table "better_together_ai_log_translations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "request", null: false
    t.text "response"
    t.string "model", null: false
    t.integer "prompt_tokens", default: 0, null: false
    t.integer "completion_tokens", default: 0, null: false
    t.integer "tokens_used", default: 0, null: false
    t.decimal "estimated_cost", precision: 10, scale: 5, default: "0.0", null: false
    t.datetime "start_time"
    t.datetime "end_time"
    t.string "status", default: "pending", null: false
    t.uuid "initiator_id"
    t.string "source_locale", null: false
    t.string "target_locale", null: false
    t.index ["initiator_id"], name: "index_better_together_ai_log_translations_on_initiator_id"
    t.index ["model"], name: "index_better_together_ai_log_translations_on_model"
    t.index ["source_locale"], name: "index_better_together_ai_log_translations_on_source_locale"
    t.index ["status"], name: "index_better_together_ai_log_translations_on_status"
    t.index ["target_locale"], name: "index_better_together_ai_log_translations_on_target_locale"
  end

  create_table "better_together_authorships", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "position", null: false
    t.string "authorable_type", null: false
    t.uuid "authorable_id", null: false
    t.uuid "author_id", null: false
    t.uuid "creator_id"
    t.index ["author_id"], name: "by_authorship_author"
    t.index ["authorable_type", "authorable_id"], name: "by_authorship_authorable"
    t.index ["creator_id"], name: "by_better_together_authorships_creator"
  end

  create_table "better_together_calendar_entries", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "calendar_id"
    t.string "schedulable_type"
    t.uuid "schedulable_id"
    t.datetime "starts_at", null: false
    t.datetime "ends_at"
    t.decimal "duration_minutes"
    t.uuid "event_id", null: false
    t.index ["calendar_id", "event_id"], name: "by_calendar_and_event", unique: true
    t.index ["calendar_id"], name: "index_better_together_calendar_entries_on_calendar_id"
    t.index ["ends_at"], name: "bt_calendar_events_by_ends_at"
    t.index ["event_id"], name: "bt_calendar_entries_by_event"
    t.index ["schedulable_type", "schedulable_id"], name: "index_better_together_calendar_entries_on_schedulable"
    t.index ["starts_at"], name: "bt_calendar_events_by_starts_at"
  end

  create_table "better_together_calendars", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "community_id", null: false
    t.uuid "creator_id"
    t.string "identifier", limit: 100, null: false
    t.string "locale", limit: 5, default: "en", null: false
    t.string "privacy", limit: 50, default: "private", null: false
    t.boolean "protected", default: false, null: false
    t.index ["community_id"], name: "by_better_together_calendars_community"
    t.index ["creator_id"], name: "by_better_together_calendars_creator"
    t.index ["identifier"], name: "index_better_together_calendars_on_identifier", unique: true
    t.index ["locale"], name: "by_better_together_calendars_locale"
    t.index ["privacy"], name: "by_better_together_calendars_privacy"
  end

  create_table "better_together_calls_for_interest", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "type", default: "BetterTogether::CallForInterest", null: false
    t.uuid "creator_id"
    t.string "identifier", limit: 100, null: false
    t.string "privacy", limit: 50, default: "private", null: false
    t.string "interestable_type"
    t.uuid "interestable_id"
    t.datetime "starts_at"
    t.datetime "ends_at"
    t.index ["creator_id"], name: "by_better_together_calls_for_interest_creator"
    t.index ["ends_at"], name: "bt_calls_for_interest_by_ends_at"
    t.index ["identifier"], name: "index_better_together_calls_for_interest_on_identifier", unique: true
    t.index ["interestable_type", "interestable_id"], name: "index_better_together_calls_for_interest_on_interestable"
    t.index ["privacy"], name: "by_better_together_calls_for_interest_privacy"
    t.index ["starts_at"], name: "bt_calls_for_interest_by_starts_at"
  end

  create_table "better_together_categories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "identifier", limit: 100, null: false
    t.integer "position", null: false
    t.boolean "protected", default: false, null: false
    t.string "type", default: "BetterTogether::Category", null: false
    t.string "icon", default: "fas fa-icons", null: false
    t.index ["identifier", "type"], name: "index_better_together_categories_on_identifier_and_type", unique: true
  end

  create_table "better_together_categorizations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "category_type", null: false
    t.uuid "category_id", null: false
    t.string "categorizable_type", null: false
    t.uuid "categorizable_id", null: false
    t.index ["categorizable_type", "categorizable_id"], name: "index_better_together_categorizations_on_categorizable"
    t.index ["category_type", "category_id"], name: "index_better_together_categorizations_on_category"
  end

  create_table "better_together_comments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "commentable_type", null: false
    t.uuid "commentable_id", null: false
    t.uuid "creator_id"
    t.text "content", default: "", null: false
    t.index ["commentable_type", "commentable_id"], name: "bt_comments_on_commentable"
    t.index ["creator_id"], name: "by_better_together_comments_creator"
  end

  create_table "better_together_communities", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "identifier", limit: 100, null: false
    t.boolean "host", default: false, null: false
    t.boolean "protected", default: false, null: false
    t.string "privacy", limit: 50, default: "private", null: false
    t.uuid "creator_id"
    t.string "type", default: "BetterTogether::Community", null: false
    t.index ["creator_id"], name: "by_creator"
    t.index ["host"], name: "index_better_together_communities_on_host", unique: true, where: "(host IS TRUE)"
    t.index ["identifier"], name: "index_better_together_communities_on_identifier", unique: true
    t.index ["privacy"], name: "by_community_privacy"
  end

  create_table "better_together_contact_details", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "contactable_type", null: false
    t.uuid "contactable_id", null: false
    t.string "type", default: "BetterTogether::ContactDetail", null: false
    t.string "name"
    t.string "role"
    t.index ["contactable_type", "contactable_id"], name: "index_better_together_contact_details_on_contactable"
  end

  create_table "better_together_content_blocks", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "type", null: false
    t.string "identifier", limit: 100
    t.jsonb "accessibility_attributes", default: {}, null: false
    t.jsonb "content_settings", default: {}, null: false
    t.jsonb "css_settings", default: {}, null: false
    t.jsonb "data_attributes", default: {}, null: false
    t.jsonb "html_attributes", default: {}, null: false
    t.jsonb "layout_settings", default: {}, null: false
    t.jsonb "media_settings", default: {}, null: false
    t.jsonb "content_data", default: {}
    t.uuid "creator_id"
    t.string "privacy", limit: 50, default: "private", null: false
    t.boolean "visible", default: true, null: false
    t.jsonb "content_area_settings", default: {}, null: false
    t.index ["creator_id"], name: "by_better_together_content_blocks_creator"
    t.index ["privacy"], name: "by_better_together_content_blocks_privacy"
  end

  create_table "better_together_content_page_blocks", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "page_id", null: false
    t.uuid "block_id", null: false
    t.integer "position", null: false
    t.index ["block_id"], name: "index_better_together_content_page_blocks_on_block_id"
    t.index ["page_id", "block_id", "position"], name: "content_page_blocks_on_page_block_and_position"
    t.index ["page_id", "block_id"], name: "content_page_blocks_on_page_and_block", unique: true
    t.index ["page_id"], name: "index_better_together_content_page_blocks_on_page_id"
  end

  create_table "better_together_content_platform_blocks", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "platform_id", null: false
    t.uuid "block_id", null: false
    t.index ["block_id"], name: "index_better_together_content_platform_blocks_on_block_id"
    t.index ["platform_id"], name: "index_better_together_content_platform_blocks_on_platform_id"
  end

  create_table "better_together_conversation_participants", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "conversation_id", null: false
    t.uuid "person_id", null: false
    t.index ["conversation_id"], name: "idx_on_conversation_id_30b3b70bad"
    t.index ["person_id"], name: "index_better_together_conversation_participants_on_person_id"
  end

  create_table "better_together_conversations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "title", null: false
    t.uuid "creator_id", null: false
    t.index ["creator_id"], name: "index_better_together_conversations_on_creator_id"
  end

  create_table "better_together_email_addresses", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "email", null: false
    t.string "label", null: false
    t.string "privacy", limit: 50, default: "private", null: false
    t.uuid "contact_detail_id", null: false
    t.boolean "primary_flag", default: false, null: false
    t.index ["contact_detail_id", "primary_flag"], name: "index_bt_email_addresses_on_contact_detail_id_and_primary", unique: true, where: "(primary_flag IS TRUE)"
    t.index ["contact_detail_id"], name: "index_better_together_email_addresses_on_contact_detail_id"
    t.index ["privacy"], name: "by_better_together_email_addresses_privacy"
  end

  create_table "better_together_event_attendances", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "event_id", null: false
    t.uuid "person_id", null: false
    t.string "status", default: "interested", null: false
    t.index ["event_id", "person_id"], name: "by_event_and_person", unique: true
    t.index ["event_id"], name: "bt_event_attendance_by_event"
    t.index ["person_id"], name: "bt_event_attendance_by_person"
  end

  create_table "better_together_event_hosts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "event_id"
    t.string "host_type"
    t.uuid "host_id"
    t.index ["event_id"], name: "index_better_together_event_hosts_on_event_id"
    t.index ["host_type", "host_id"], name: "index_better_together_event_hosts_on_host"
  end

  create_table "better_together_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "type", default: "BetterTogether::Event", null: false
    t.uuid "creator_id"
    t.string "identifier", limit: 100, null: false
    t.string "privacy", limit: 50, default: "private", null: false
    t.datetime "starts_at"
    t.datetime "ends_at"
    t.decimal "duration_minutes"
    t.string "registration_url"
    t.index ["creator_id"], name: "by_better_together_events_creator"
    t.index ["ends_at"], name: "bt_events_by_ends_at"
    t.index ["identifier"], name: "index_better_together_events_on_identifier", unique: true
    t.index ["privacy"], name: "by_better_together_events_privacy"
    t.index ["starts_at"], name: "bt_events_by_starts_at"
  end

  create_table "better_together_geography_continents", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "identifier", limit: 100, null: false
    t.boolean "protected", default: false, null: false
    t.uuid "community_id", null: false
    t.index ["community_id"], name: "by_geography_continent_community"
    t.index ["identifier"], name: "index_better_together_geography_continents_on_identifier", unique: true
  end

  create_table "better_together_geography_countries", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "identifier", limit: 100, null: false
    t.string "iso_code", limit: 2, null: false
    t.boolean "protected", default: false, null: false
    t.uuid "community_id", null: false
    t.index ["community_id"], name: "by_geography_country_community"
    t.index ["identifier"], name: "index_better_together_geography_countries_on_identifier", unique: true
    t.index ["iso_code"], name: "index_better_together_geography_countries_on_iso_code", unique: true
  end

  create_table "better_together_geography_country_continents", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "country_id"
    t.uuid "continent_id"
    t.index ["continent_id"], name: "country_continent_by_continent"
    t.index ["country_id", "continent_id"], name: "index_country_continents_on_country_and_continent", unique: true
    t.index ["country_id"], name: "country_continent_by_country"
  end

  create_table "better_together_geography_geospatial_spaces", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "geospatial_type"
    t.uuid "geospatial_id"
    t.integer "position", null: false
    t.boolean "primary_flag", default: false, null: false
    t.uuid "space_id"
    t.index ["geospatial_id", "primary_flag"], name: "index_geospatial_spaces_on_geospatial_id_and_primary", unique: true, where: "(primary_flag IS TRUE)"
    t.index ["geospatial_type", "geospatial_id"], name: "index_better_together_geography_geospatial_spaces_on_geospatial"
    t.index ["space_id"], name: "index_better_together_geography_geospatial_spaces_on_space_id"
  end

  create_table "better_together_geography_locatable_locations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "creator_id"
    t.string "location_type"
    t.uuid "location_id"
    t.string "locatable_type", null: false
    t.uuid "locatable_id", null: false
    t.string "name"
    t.index ["creator_id"], name: "by_better_together_geography_locatable_locations_creator"
    t.index ["locatable_id", "locatable_type", "location_id", "location_type"], name: "locatable_locations"
    t.index ["locatable_type", "locatable_id"], name: "locatable_location_by_locatable"
    t.index ["location_type", "location_id"], name: "locatable_location_by_location"
    t.index ["name"], name: "locatable_location_by_name"
  end

  create_table "better_together_geography_maps", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "creator_id"
    t.string "identifier", limit: 100, null: false
    t.string "locale", limit: 5, default: "en", null: false
    t.string "privacy", limit: 50, default: "private", null: false
    t.boolean "protected", default: false, null: false
    t.geography "center", limit: {srid: 4326, type: "st_point", geographic: true}
    t.integer "zoom", default: 13, null: false
    t.geography "viewport", limit: {srid: 4326, type: "st_polygon", geographic: true}
    t.jsonb "metadata", default: {}, null: false
    t.string "mappable_type"
    t.uuid "mappable_id"
    t.string "type", default: "BetterTogether::Geography::Map", null: false
    t.index ["creator_id"], name: "by_better_together_geography_maps_creator"
    t.index ["identifier"], name: "index_better_together_geography_maps_on_identifier", unique: true
    t.index ["locale"], name: "by_better_together_geography_maps_locale"
    t.index ["mappable_type", "mappable_id"], name: "index_better_together_geography_maps_on_mappable"
    t.index ["privacy"], name: "by_better_together_geography_maps_privacy"
  end

  create_table "better_together_geography_region_settlements", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "protected", default: false, null: false
    t.uuid "region_id"
    t.uuid "settlement_id"
    t.index ["region_id"], name: "bt_region_settlement_by_region"
    t.index ["settlement_id"], name: "bt_region_settlement_by_settlement"
  end

  create_table "better_together_geography_regions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "identifier", limit: 100, null: false
    t.boolean "protected", default: false, null: false
    t.uuid "community_id", null: false
    t.uuid "country_id"
    t.uuid "state_id"
    t.string "type", default: "BetterTogether::Geography::Region", null: false
    t.index ["community_id"], name: "by_geography_region_community"
    t.index ["country_id"], name: "index_better_together_geography_regions_on_country_id"
    t.index ["identifier"], name: "index_better_together_geography_regions_on_identifier", unique: true
    t.index ["state_id"], name: "index_better_together_geography_regions_on_state_id"
  end

  create_table "better_together_geography_settlements", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "identifier", limit: 100, null: false
    t.boolean "protected", default: false, null: false
    t.uuid "community_id", null: false
    t.uuid "country_id"
    t.uuid "state_id"
    t.index ["community_id"], name: "by_geography_settlement_community"
    t.index ["country_id"], name: "index_better_together_geography_settlements_on_country_id"
    t.index ["identifier"], name: "index_better_together_geography_settlements_on_identifier", unique: true
    t.index ["state_id"], name: "index_better_together_geography_settlements_on_state_id"
  end

  create_table "better_together_geography_spaces", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "creator_id"
    t.string "identifier", limit: 100, null: false
    t.float "elevation"
    t.float "latitude"
    t.float "longitude"
    t.jsonb "properties", default: {}
    t.jsonb "metadata", default: {}
    t.index ["creator_id"], name: "by_better_together_geography_spaces_creator"
    t.index ["identifier"], name: "index_better_together_geography_spaces_on_identifier", unique: true
  end

  create_table "better_together_geography_states", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "identifier", limit: 100, null: false
    t.string "iso_code", limit: 5, null: false
    t.boolean "protected", default: false, null: false
    t.uuid "community_id", null: false
    t.uuid "country_id"
    t.index ["community_id"], name: "by_geography_state_community"
    t.index ["country_id"], name: "index_better_together_geography_states_on_country_id"
    t.index ["identifier"], name: "index_better_together_geography_states_on_identifier", unique: true
    t.index ["iso_code"], name: "index_better_together_geography_states_on_iso_code", unique: true
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

  create_table "better_together_infrastructure_building_connections", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "building_id", null: false
    t.string "connection_type", null: false
    t.uuid "connection_id", null: false
    t.integer "position", null: false
    t.boolean "primary_flag", default: false, null: false
    t.index ["building_id"], name: "bt_building_connections_building"
    t.index ["connection_id", "primary_flag"], name: "index_bt_building_connections_on_connection_id_and_primary", unique: true, where: "(primary_flag IS TRUE)"
    t.index ["connection_type", "connection_id"], name: "bt_building_connections_connection"
  end

  create_table "better_together_infrastructure_buildings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "type", default: "BetterTogether::Infrastructure::Building", null: false
    t.uuid "community_id", null: false
    t.uuid "creator_id"
    t.string "identifier", limit: 100, null: false
    t.string "privacy", limit: 50, default: "private", null: false
    t.integer "floors_count", default: 0, null: false
    t.integer "rooms_count", default: 0, null: false
    t.uuid "address_id"
    t.index ["address_id"], name: "index_better_together_infrastructure_buildings_on_address_id"
    t.index ["community_id"], name: "by_better_together_infrastructure_buildings_community"
    t.index ["creator_id"], name: "by_better_together_infrastructure_buildings_creator"
    t.index ["identifier"], name: "index_better_together_infrastructure_buildings_on_identifier", unique: true
    t.index ["privacy"], name: "by_better_together_infrastructure_buildings_privacy"
  end

  create_table "better_together_infrastructure_floors", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "building_id"
    t.uuid "community_id", null: false
    t.uuid "creator_id"
    t.string "identifier", limit: 100, null: false
    t.string "privacy", limit: 50, default: "private", null: false
    t.integer "position", null: false
    t.integer "level", default: 0, null: false
    t.integer "rooms_count", default: 0, null: false
    t.index ["building_id"], name: "index_better_together_infrastructure_floors_on_building_id"
    t.index ["community_id"], name: "by_better_together_infrastructure_floors_community"
    t.index ["creator_id"], name: "by_better_together_infrastructure_floors_creator"
    t.index ["identifier"], name: "index_better_together_infrastructure_floors_on_identifier", unique: true
    t.index ["privacy"], name: "by_better_together_infrastructure_floors_privacy"
  end

  create_table "better_together_infrastructure_rooms", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "floor_id"
    t.uuid "community_id", null: false
    t.uuid "creator_id"
    t.string "identifier", limit: 100, null: false
    t.string "privacy", limit: 50, default: "private", null: false
    t.index ["community_id"], name: "by_better_together_infrastructure_rooms_community"
    t.index ["creator_id"], name: "by_better_together_infrastructure_rooms_creator"
    t.index ["floor_id"], name: "index_better_together_infrastructure_rooms_on_floor_id"
    t.index ["identifier"], name: "index_better_together_infrastructure_rooms_on_identifier", unique: true
    t.index ["privacy"], name: "by_better_together_infrastructure_rooms_privacy"
  end

  create_table "better_together_invitations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "type", default: "BetterTogether::Invitation", null: false
    t.string "status", limit: 20, null: false
    t.datetime "valid_from", null: false
    t.datetime "valid_until"
    t.datetime "last_sent"
    t.datetime "accepted_at"
    t.string "locale", limit: 5, default: "en", null: false
    t.string "token", limit: 24, null: false
    t.string "invitable_type", null: false
    t.uuid "invitable_id", null: false
    t.string "inviter_type", null: false
    t.uuid "inviter_id", null: false
    t.string "invitee_type", null: false
    t.uuid "invitee_id", null: false
    t.string "invitee_email", null: false
    t.uuid "role_id"
    t.index ["invitable_id", "status"], name: "invitations_on_invitable_id_and_status"
    t.index ["invitable_type", "invitable_id"], name: "by_invitable"
    t.index ["invitee_email", "invitable_id"], name: "invitations_on_invitee_email_and_invitable_id", unique: true
    t.index ["invitee_email"], name: "invitations_by_invitee_email"
    t.index ["invitee_email"], name: "pending_invites_on_invitee_email", where: "((status)::text = 'pending'::text)"
    t.index ["invitee_type", "invitee_id"], name: "by_invitee"
    t.index ["inviter_type", "inviter_id"], name: "by_inviter"
    t.index ["locale"], name: "by_better_together_invitations_locale"
    t.index ["role_id"], name: "by_role"
    t.index ["status"], name: "by_status"
    t.index ["token"], name: "invitations_by_token", unique: true
    t.index ["valid_from"], name: "by_valid_from"
    t.index ["valid_until"], name: "by_valid_until"
  end

  create_table "better_together_joatu_agreements", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "offer_id", null: false
    t.uuid "request_id", null: false
    t.text "terms"
    t.string "value"
    t.string "status", default: "pending", null: false
    t.index ["offer_id", "request_id"], name: "bt_joatu_agreements_unique_offer_request", unique: true
    t.index ["offer_id"], name: "bt_joatu_agreements_by_offer"
    t.index ["offer_id"], name: "bt_joatu_agreements_one_accepted_per_offer", unique: true, where: "((status)::text = 'accepted'::text)"
    t.index ["request_id"], name: "bt_joatu_agreements_by_request"
    t.index ["request_id"], name: "bt_joatu_agreements_one_accepted_per_request", unique: true, where: "((status)::text = 'accepted'::text)"
  end

  create_table "better_together_joatu_offers", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "creator_id"
    t.string "status", default: "open", null: false
    t.string "target_type"
    t.uuid "target_id"
    t.string "urgency", default: "normal", null: false
    t.uuid "address_id"
    t.index ["address_id"], name: "index_better_together_joatu_offers_on_address_id"
    t.index ["creator_id"], name: "by_better_together_joatu_offers_creator"
    t.index ["target_type", "target_id"], name: "bt_joatu_offers_on_target"
  end

  create_table "better_together_joatu_requests", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "creator_id"
    t.string "status", default: "open", null: false
    t.string "target_type"
    t.uuid "target_id"
    t.string "urgency", default: "normal", null: false
    t.uuid "address_id"
    t.index ["address_id"], name: "index_better_together_joatu_requests_on_address_id"
    t.index ["creator_id"], name: "by_better_together_joatu_requests_creator"
    t.index ["target_type", "target_id"], name: "bt_joatu_requests_on_target"
  end

  create_table "better_together_joatu_response_links", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "source_type", null: false
    t.uuid "source_id", null: false
    t.string "response_type", null: false
    t.uuid "response_id", null: false
    t.uuid "creator_id"
    t.index ["creator_id"], name: "by_better_together_joatu_response_links_creator"
    t.index ["response_type", "response_id"], name: "bt_joatu_response_links_by_response"
    t.index ["source_type", "source_id", "response_type", "response_id"], name: "bt_joatu_response_links_unique_pair", unique: true
    t.index ["source_type", "source_id"], name: "bt_joatu_response_links_by_source"
  end

  create_table "better_together_jwt_denylists", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "jti"
    t.datetime "exp"
    t.index ["jti"], name: "index_better_together_jwt_denylists_on_jti"
  end

  create_table "better_together_messages", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "content"
    t.uuid "sender_id", null: false
    t.uuid "conversation_id", null: false
    t.index ["conversation_id"], name: "index_better_together_messages_on_conversation_id"
    t.index ["sender_id"], name: "index_better_together_messages_on_sender_id"
  end

  create_table "better_together_metrics_downloads", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "locale", limit: 5, default: "en", null: false
    t.string "downloadable_type"
    t.uuid "downloadable_id"
    t.string "file_name", null: false
    t.string "file_type", null: false
    t.bigint "file_size", null: false
    t.datetime "downloaded_at", null: false
    t.index ["downloadable_type", "downloadable_id"], name: "index_better_together_metrics_downloads_on_downloadable"
    t.index ["locale"], name: "by_better_together_metrics_downloads_locale"
  end

  create_table "better_together_metrics_link_click_reports", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "filters", default: {}, null: false
    t.boolean "sort_by_total_clicks", default: false, null: false
    t.string "file_format", default: "csv", null: false
    t.jsonb "report_data", default: {}, null: false
    t.index ["filters"], name: "index_better_together_metrics_link_click_reports_on_filters", using: :gin
  end

  create_table "better_together_metrics_link_clicks", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.string "page_url", null: false
    t.string "locale", null: false
    t.boolean "internal", default: true
    t.datetime "clicked_at", null: false
  end

  create_table "better_together_metrics_page_view_reports", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "filters", default: {}, null: false
    t.boolean "sort_by_total_views", default: false, null: false
    t.string "file_format", default: "csv", null: false
    t.jsonb "report_data", default: {}, null: false
    t.index ["filters"], name: "index_better_together_metrics_page_view_reports_on_filters", using: :gin
  end

  create_table "better_together_metrics_page_views", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "locale", limit: 5, default: "en", null: false
    t.string "pageable_type"
    t.uuid "pageable_id"
    t.datetime "viewed_at", null: false
    t.string "page_url"
    t.index ["locale"], name: "by_better_together_metrics_page_views_locale"
    t.index ["pageable_type", "pageable_id"], name: "index_better_together_metrics_page_views_on_pageable"
  end

  create_table "better_together_metrics_search_queries", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "locale", limit: 5, default: "en", null: false
    t.string "query", null: false
    t.integer "results_count", null: false
    t.datetime "searched_at", null: false
    t.index ["locale"], name: "by_better_together_metrics_search_queries_locale"
  end

  create_table "better_together_metrics_shares", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "locale", limit: 5, default: "en", null: false
    t.string "platform", null: false
    t.string "url", null: false
    t.datetime "shared_at", null: false
    t.string "shareable_type"
    t.uuid "shareable_id"
    t.index ["locale"], name: "by_better_together_metrics_shares_locale"
    t.index ["platform", "url"], name: "index_better_together_metrics_shares_on_platform_and_url"
    t.index ["shareable_type", "shareable_id"], name: "index_better_together_metrics_shares_on_shareable"
  end

  create_table "better_together_navigation_areas", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "identifier", limit: 100, null: false
    t.boolean "protected", default: false, null: false
    t.boolean "visible", default: true, null: false
    t.string "name"
    t.string "style"
    t.string "navigable_type"
    t.bigint "navigable_id"
    t.index ["identifier"], name: "index_better_together_navigation_areas_on_identifier", unique: true
    t.index ["navigable_type", "navigable_id"], name: "by_navigable"
  end

  create_table "better_together_navigation_items", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "identifier", limit: 100, null: false
    t.integer "position", null: false
    t.boolean "protected", default: false, null: false
    t.boolean "visible", default: true, null: false
    t.uuid "navigation_area_id", null: false
    t.uuid "parent_id"
    t.string "url"
    t.string "icon"
    t.string "item_type", null: false
    t.string "linkable_type"
    t.uuid "linkable_id"
    t.string "route_name"
    t.integer "children_count", default: 0, null: false
    t.index ["identifier"], name: "index_better_together_navigation_items_on_identifier", unique: true
    t.index ["linkable_type", "linkable_id"], name: "by_linkable"
    t.index ["navigation_area_id", "parent_id", "position"], name: "navigation_items_area_position", unique: true
    t.index ["navigation_area_id"], name: "index_better_together_navigation_items_on_navigation_area_id"
    t.index ["parent_id"], name: "by_nav_item_parent"
  end

  create_table "better_together_pages", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "identifier", limit: 100, null: false
    t.boolean "protected", default: false, null: false
    t.string "privacy", limit: 50, default: "private", null: false
    t.text "meta_description"
    t.string "keywords"
    t.datetime "published_at"
    t.string "layout"
    t.string "template"
    t.uuid "sidebar_nav_id"
    t.index ["identifier"], name: "index_better_together_pages_on_identifier", unique: true
    t.index ["privacy"], name: "by_page_privacy"
    t.index ["published_at"], name: "by_page_publication_date"
    t.index ["sidebar_nav_id"], name: "by_page_sidebar_nav"
  end

  create_table "better_together_people", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "identifier", limit: 100, null: false
    t.uuid "community_id", null: false
    t.jsonb "preferences", default: {}, null: false
    t.string "privacy", limit: 50, default: "private", null: false
    t.jsonb "notification_preferences", default: {}, null: false
    t.index ["community_id"], name: "by_person_community"
    t.index ["identifier"], name: "index_better_together_people_on_identifier", unique: true
    t.index ["privacy"], name: "by_better_together_people_privacy"
  end

  create_table "better_together_person_blocks", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "blocker_id", null: false
    t.uuid "blocked_id", null: false
    t.index ["blocked_id"], name: "index_better_together_person_blocks_on_blocked_id"
    t.index ["blocker_id", "blocked_id"], name: "unique_person_blocks", unique: true
    t.index ["blocker_id"], name: "index_better_together_person_blocks_on_blocker_id"
  end

  create_table "better_together_person_community_memberships", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "member_id", null: false
    t.uuid "joinable_id", null: false
    t.uuid "role_id", null: false
    t.index ["joinable_id", "member_id", "role_id"], name: "unique_person_community_membership_member_role", unique: true
    t.index ["joinable_id"], name: "person_community_membership_by_joinable"
    t.index ["member_id"], name: "person_community_membership_by_member"
    t.index ["role_id"], name: "person_community_membership_by_role"
  end

  create_table "better_together_person_platform_memberships", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "member_id", null: false
    t.uuid "joinable_id", null: false
    t.uuid "role_id", null: false
    t.index ["joinable_id", "member_id", "role_id"], name: "unique_person_platform_membership_member_role", unique: true
    t.index ["joinable_id"], name: "person_platform_membership_by_joinable"
    t.index ["member_id"], name: "person_platform_membership_by_member"
    t.index ["role_id"], name: "person_platform_membership_by_role"
  end

  create_table "better_together_phone_numbers", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "number", null: false
    t.string "label", null: false
    t.string "privacy", limit: 50, default: "private", null: false
    t.uuid "contact_detail_id", null: false
    t.boolean "primary_flag", default: false, null: false
    t.index ["contact_detail_id", "primary_flag"], name: "index_bt_phone_numbers_on_contact_detail_id_and_primary", unique: true, where: "(primary_flag IS TRUE)"
    t.index ["contact_detail_id"], name: "index_better_together_phone_numbers_on_contact_detail_id"
    t.index ["privacy"], name: "by_better_together_phone_numbers_privacy"
  end

  create_table "better_together_places", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "community_id", null: false
    t.uuid "creator_id"
    t.string "identifier", limit: 100, null: false
    t.uuid "space_id", null: false
    t.string "privacy", limit: 50, default: "private", null: false
    t.index ["community_id"], name: "by_better_together_places_community"
    t.index ["creator_id"], name: "by_better_together_places_creator"
    t.index ["identifier"], name: "index_better_together_places_on_identifier", unique: true
    t.index ["privacy"], name: "by_better_together_places_privacy"
    t.index ["space_id"], name: "index_better_together_places_on_space_id"
  end

  create_table "better_together_platform_invitations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "community_role_id", null: false
    t.string "invitee_email"
    t.uuid "invitable_id", null: false
    t.uuid "invitee_id"
    t.uuid "inviter_id", null: false
    t.uuid "platform_role_id"
    t.string "status", limit: 20, null: false
    t.string "locale", limit: 5, default: "en", null: false
    t.string "token", limit: 24, null: false
    t.datetime "valid_from", null: false
    t.datetime "valid_until"
    t.datetime "last_sent"
    t.datetime "accepted_at"
    t.string "type", default: "BetterTogether::PlatformInvitation", null: false
    t.integer "session_duration_mins", default: 30, null: false
    t.index ["community_role_id"], name: "platform_invitations_by_community_role"
    t.index ["invitable_id", "status"], name: "index_platform_invitations_on_invitable_id_and_status"
    t.index ["invitable_id"], name: "platform_invitations_by_invitable"
    t.index ["invitee_email", "invitable_id"], name: "idx_on_invitee_email_invitable_id_5a7d642388", unique: true
    t.index ["invitee_email"], name: "index_pending_invitations_on_invitee_email", where: "((status)::text = 'pending'::text)"
    t.index ["invitee_email"], name: "platform_invitations_by_invitee_email"
    t.index ["invitee_id"], name: "platform_invitations_by_invitee"
    t.index ["inviter_id"], name: "platform_invitations_by_inviter"
    t.index ["locale"], name: "by_better_together_platform_invitations_locale"
    t.index ["platform_role_id"], name: "platform_invitations_by_platform_role"
    t.index ["status"], name: "platform_invitations_by_status"
    t.index ["token"], name: "platform_invitations_by_token", unique: true
    t.index ["valid_from"], name: "platform_invitations_by_valid_from"
    t.index ["valid_until"], name: "platform_invitations_by_valid_until"
  end

  create_table "better_together_platforms", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "identifier", limit: 100, null: false
    t.boolean "host", default: false, null: false
    t.boolean "protected", default: false, null: false
    t.uuid "community_id", null: false
    t.string "privacy", limit: 50, default: "private", null: false
    t.string "url", null: false
    t.string "time_zone", null: false
    t.jsonb "settings", default: {}, null: false
    t.index ["community_id"], name: "by_platform_community"
    t.index ["host"], name: "index_better_together_platforms_on_host", unique: true, where: "(host IS TRUE)"
    t.index ["identifier"], name: "index_better_together_platforms_on_identifier", unique: true
    t.index ["privacy"], name: "by_platform_privacy"
    t.index ["url"], name: "index_better_together_platforms_on_url", unique: true
  end

  create_table "better_together_posts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "type", default: "BetterTogether::Post", null: false
    t.string "identifier", limit: 100, null: false
    t.boolean "protected", default: false, null: false
    t.string "privacy", limit: 50, default: "private", null: false
    t.datetime "published_at"
    t.uuid "creator_id"
    t.index ["creator_id"], name: "by_better_together_posts_creator"
    t.index ["identifier"], name: "index_better_together_posts_on_identifier", unique: true
    t.index ["privacy"], name: "by_better_together_posts_privacy"
    t.index ["published_at"], name: "by_post_publication_date"
  end

  create_table "better_together_reports", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "reporter_id", null: false
    t.uuid "reportable_id", null: false
    t.string "reportable_type", null: false
    t.text "reason"
    t.index ["reporter_id"], name: "index_better_together_reports_on_reporter_id"
  end

  create_table "better_together_resource_permissions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "identifier", limit: 100, null: false
    t.boolean "protected", default: false, null: false
    t.integer "position", null: false
    t.string "resource_type", null: false
    t.string "action", null: false
    t.string "target", null: false
    t.index ["identifier"], name: "index_better_together_resource_permissions_on_identifier", unique: true
    t.index ["resource_type", "position"], name: "index_resource_permissions_on_resource_type_and_position", unique: true
  end

  create_table "better_together_role_resource_permissions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "role_id", null: false
    t.uuid "resource_permission_id", null: false
    t.index ["resource_permission_id"], name: "role_resource_permissions_resource_permission"
    t.index ["role_id", "resource_permission_id"], name: "unique_role_resource_permission_index", unique: true
    t.index ["role_id"], name: "role_resource_permissions_role"
  end

  create_table "better_together_roles", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "identifier", limit: 100, null: false
    t.boolean "protected", default: false, null: false
    t.integer "position", null: false
    t.string "resource_type", null: false
    t.string "type", default: "BetterTogether::Role", null: false
    t.index ["identifier"], name: "index_better_together_roles_on_identifier", unique: true
    t.index ["resource_type", "position"], name: "index_roles_on_resource_type_and_position", unique: true
  end

  create_table "better_together_social_media_accounts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "platform", null: false
    t.string "handle", null: false
    t.string "url"
    t.string "privacy", limit: 50, default: "private", null: false
    t.uuid "contact_detail_id", null: false
    t.index ["contact_detail_id", "platform"], name: "index_bt_sma_on_contact_detail_and_platform", unique: true
    t.index ["contact_detail_id"], name: "idx_on_contact_detail_id_6380b64b3b"
    t.index ["privacy"], name: "by_better_together_social_media_accounts_privacy"
  end

  create_table "better_together_uploads", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "creator_id"
    t.string "identifier", limit: 100, null: false
    t.string "privacy", limit: 50, default: "private", null: false
    t.string "type", default: "BetterTogether::Upload", null: false
    t.index ["creator_id"], name: "by_better_together_files_creator"
    t.index ["identifier"], name: "index_better_together_uploads_on_identifier", unique: true
    t.index ["privacy"], name: "by_better_together_files_privacy"
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
    t.string "provider"
    t.string "uid"
    t.index ["confirmation_token"], name: "index_better_together_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_better_together_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_better_together_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_better_together_users_on_unlock_token", unique: true
  end

  create_table "better_together_website_links", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.string "label", null: false
    t.string "privacy", limit: 50, default: "private", null: false
    t.uuid "contact_detail_id", null: false
    t.index ["contact_detail_id"], name: "index_better_together_website_links_on_contact_detail_id"
    t.index ["privacy"], name: "by_better_together_website_links_privacy"
  end

  create_table "better_together_wizard_step_definitions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "identifier", limit: 100, null: false
    t.boolean "protected", default: false, null: false
    t.uuid "wizard_id", null: false
    t.string "template"
    t.string "form_class"
    t.string "message", default: "Please complete this next step.", null: false
    t.integer "step_number", null: false
    t.index ["identifier"], name: "index_better_together_wizard_step_definitions_on_identifier", unique: true
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
    t.integer "max_completions", default: 0, null: false
    t.integer "current_completions", default: 0, null: false
    t.datetime "first_completed_at"
    t.datetime "last_completed_at"
    t.text "success_message", default: "Thank you. You have successfully completed the wizard", null: false
    t.string "success_path", default: "/", null: false
    t.index ["identifier"], name: "index_better_together_wizards_on_identifier", unique: true
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

  create_table "noticed_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "type"
    t.string "record_type"
    t.uuid "record_id"
    t.jsonb "params"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "notifications_count"
    t.index ["record_type", "record_id"], name: "index_noticed_events_on_record"
  end

  create_table "noticed_notifications", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "type"
    t.uuid "event_id", null: false
    t.string "recipient_type", null: false
    t.uuid "recipient_id", null: false
    t.datetime "read_at", precision: nil
    t.datetime "seen_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_noticed_notifications_on_event_id"
    t.index ["recipient_type", "recipient_id"], name: "index_noticed_notifications_on_recipient"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "better_together_addresses", "better_together_contact_details", column: "contact_detail_id"
  add_foreign_key "better_together_agreement_participants", "better_together_agreements", column: "agreement_id"
  add_foreign_key "better_together_agreement_participants", "better_together_people", column: "person_id"
  add_foreign_key "better_together_agreement_terms", "better_together_agreements", column: "agreement_id"
  add_foreign_key "better_together_agreements", "better_together_pages", column: "page_id"
  add_foreign_key "better_together_agreements", "better_together_people", column: "creator_id"
  add_foreign_key "better_together_ai_log_translations", "better_together_people", column: "initiator_id"
  add_foreign_key "better_together_authorships", "better_together_people", column: "author_id"
  add_foreign_key "better_together_calendar_entries", "better_together_calendars", column: "calendar_id"
  add_foreign_key "better_together_calendar_entries", "better_together_events", column: "event_id"
  add_foreign_key "better_together_calendars", "better_together_communities", column: "community_id"
  add_foreign_key "better_together_calendars", "better_together_people", column: "creator_id"
  add_foreign_key "better_together_calls_for_interest", "better_together_people", column: "creator_id"
  add_foreign_key "better_together_categorizations", "better_together_categories", column: "category_id"
  add_foreign_key "better_together_comments", "better_together_people", column: "creator_id"
  add_foreign_key "better_together_communities", "better_together_people", column: "creator_id"
  add_foreign_key "better_together_content_blocks", "better_together_people", column: "creator_id"
  add_foreign_key "better_together_content_page_blocks", "better_together_content_blocks", column: "block_id"
  add_foreign_key "better_together_content_page_blocks", "better_together_pages", column: "page_id"
  add_foreign_key "better_together_content_platform_blocks", "better_together_content_blocks", column: "block_id"
  add_foreign_key "better_together_content_platform_blocks", "better_together_platforms", column: "platform_id"
  add_foreign_key "better_together_conversation_participants", "better_together_conversations", column: "conversation_id"
  add_foreign_key "better_together_conversation_participants", "better_together_people", column: "person_id"
  add_foreign_key "better_together_conversations", "better_together_people", column: "creator_id"
  add_foreign_key "better_together_email_addresses", "better_together_contact_details", column: "contact_detail_id"
  add_foreign_key "better_together_event_attendances", "better_together_events", column: "event_id"
  add_foreign_key "better_together_event_attendances", "better_together_people", column: "person_id"
  add_foreign_key "better_together_event_hosts", "better_together_events", column: "event_id"
  add_foreign_key "better_together_events", "better_together_people", column: "creator_id"
  add_foreign_key "better_together_geography_continents", "better_together_communities", column: "community_id"
  add_foreign_key "better_together_geography_countries", "better_together_communities", column: "community_id"
  add_foreign_key "better_together_geography_country_continents", "better_together_geography_continents", column: "continent_id"
  add_foreign_key "better_together_geography_country_continents", "better_together_geography_countries", column: "country_id"
  add_foreign_key "better_together_geography_geospatial_spaces", "better_together_geography_spaces", column: "space_id"
  add_foreign_key "better_together_geography_locatable_locations", "better_together_people", column: "creator_id"
  add_foreign_key "better_together_geography_maps", "better_together_people", column: "creator_id"
  add_foreign_key "better_together_geography_region_settlements", "better_together_geography_regions", column: "region_id"
  add_foreign_key "better_together_geography_region_settlements", "better_together_geography_settlements", column: "settlement_id"
  add_foreign_key "better_together_geography_regions", "better_together_communities", column: "community_id"
  add_foreign_key "better_together_geography_regions", "better_together_geography_countries", column: "country_id"
  add_foreign_key "better_together_geography_regions", "better_together_geography_states", column: "state_id"
  add_foreign_key "better_together_geography_settlements", "better_together_communities", column: "community_id"
  add_foreign_key "better_together_geography_settlements", "better_together_geography_countries", column: "country_id"
  add_foreign_key "better_together_geography_settlements", "better_together_geography_states", column: "state_id"
  add_foreign_key "better_together_geography_spaces", "better_together_people", column: "creator_id"
  add_foreign_key "better_together_geography_states", "better_together_communities", column: "community_id"
  add_foreign_key "better_together_geography_states", "better_together_geography_countries", column: "country_id"
  add_foreign_key "better_together_infrastructure_building_connections", "better_together_infrastructure_buildings", column: "building_id"
  add_foreign_key "better_together_infrastructure_buildings", "better_together_addresses", column: "address_id"
  add_foreign_key "better_together_infrastructure_buildings", "better_together_communities", column: "community_id"
  add_foreign_key "better_together_infrastructure_buildings", "better_together_people", column: "creator_id"
  add_foreign_key "better_together_infrastructure_floors", "better_together_communities", column: "community_id"
  add_foreign_key "better_together_infrastructure_floors", "better_together_infrastructure_buildings", column: "building_id"
  add_foreign_key "better_together_infrastructure_floors", "better_together_people", column: "creator_id"
  add_foreign_key "better_together_infrastructure_rooms", "better_together_communities", column: "community_id"
  add_foreign_key "better_together_infrastructure_rooms", "better_together_infrastructure_floors", column: "floor_id"
  add_foreign_key "better_together_infrastructure_rooms", "better_together_people", column: "creator_id"
  add_foreign_key "better_together_invitations", "better_together_roles", column: "role_id"
  add_foreign_key "better_together_joatu_agreements", "better_together_joatu_offers", column: "offer_id"
  add_foreign_key "better_together_joatu_agreements", "better_together_joatu_requests", column: "request_id"
  add_foreign_key "better_together_joatu_offers", "better_together_addresses", column: "address_id"
  add_foreign_key "better_together_joatu_offers", "better_together_people", column: "creator_id"
  add_foreign_key "better_together_joatu_requests", "better_together_addresses", column: "address_id"
  add_foreign_key "better_together_joatu_requests", "better_together_people", column: "creator_id"
  add_foreign_key "better_together_joatu_response_links", "better_together_people", column: "creator_id"
  add_foreign_key "better_together_messages", "better_together_conversations", column: "conversation_id"
  add_foreign_key "better_together_messages", "better_together_people", column: "sender_id"
  add_foreign_key "better_together_navigation_items", "better_together_navigation_areas", column: "navigation_area_id"
  add_foreign_key "better_together_navigation_items", "better_together_navigation_items", column: "parent_id"
  add_foreign_key "better_together_pages", "better_together_navigation_areas", column: "sidebar_nav_id"
  add_foreign_key "better_together_people", "better_together_communities", column: "community_id"
  add_foreign_key "better_together_person_blocks", "better_together_people", column: "blocked_id"
  add_foreign_key "better_together_person_blocks", "better_together_people", column: "blocker_id"
  add_foreign_key "better_together_person_community_memberships", "better_together_communities", column: "joinable_id"
  add_foreign_key "better_together_person_community_memberships", "better_together_people", column: "member_id"
  add_foreign_key "better_together_person_community_memberships", "better_together_roles", column: "role_id"
  add_foreign_key "better_together_person_platform_memberships", "better_together_people", column: "member_id"
  add_foreign_key "better_together_person_platform_memberships", "better_together_platforms", column: "joinable_id"
  add_foreign_key "better_together_person_platform_memberships", "better_together_roles", column: "role_id"
  add_foreign_key "better_together_phone_numbers", "better_together_contact_details", column: "contact_detail_id"
  add_foreign_key "better_together_places", "better_together_communities", column: "community_id"
  add_foreign_key "better_together_places", "better_together_geography_spaces", column: "space_id"
  add_foreign_key "better_together_places", "better_together_people", column: "creator_id"
  add_foreign_key "better_together_platform_invitations", "better_together_people", column: "invitee_id"
  add_foreign_key "better_together_platform_invitations", "better_together_people", column: "inviter_id"
  add_foreign_key "better_together_platform_invitations", "better_together_platforms", column: "invitable_id"
  add_foreign_key "better_together_platform_invitations", "better_together_roles", column: "community_role_id"
  add_foreign_key "better_together_platform_invitations", "better_together_roles", column: "platform_role_id"
  add_foreign_key "better_together_platforms", "better_together_communities", column: "community_id"
  add_foreign_key "better_together_posts", "better_together_people", column: "creator_id"
  add_foreign_key "better_together_reports", "better_together_people", column: "reporter_id"
  add_foreign_key "better_together_role_resource_permissions", "better_together_resource_permissions", column: "resource_permission_id"
  add_foreign_key "better_together_role_resource_permissions", "better_together_roles", column: "role_id"
  add_foreign_key "better_together_social_media_accounts", "better_together_contact_details", column: "contact_detail_id"
  add_foreign_key "better_together_uploads", "better_together_people", column: "creator_id"
  add_foreign_key "better_together_website_links", "better_together_contact_details", column: "contact_detail_id"
  add_foreign_key "better_together_wizard_step_definitions", "better_together_wizards", column: "wizard_id"
  add_foreign_key "better_together_wizard_steps", "better_together_people", column: "creator_id"
  add_foreign_key "better_together_wizard_steps", "better_together_wizard_step_definitions", column: "wizard_step_definition_id"
  add_foreign_key "better_together_wizard_steps", "better_together_wizards", column: "wizard_id"
end
