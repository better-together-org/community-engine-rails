# frozen_string_literal: true

# Creates OAuth2 tables for Doorkeeper integration.
# Uses UUID primary keys and better_together_ prefix to match engine conventions.
class CreateBetterTogetherOauthTables < ActiveRecord::Migration[7.2]
  def change
    create_bt_table :oauth_applications do |t|
      t.string :name, null: false
      t.string :uid, null: false
      t.string :secret, null: false
      t.text :redirect_uri
      t.string :scopes, null: false, default: ''
      t.boolean :confidential, null: false, default: true

      t.bt_references :owner,
                      target_table: :better_together_people,
                      null: true,
                      index: { name: 'index_bt_oauth_apps_on_owner_id' }

      t.index :uid, unique: true, name: 'index_bt_oauth_apps_on_uid'
    end

    create_bt_table :oauth_access_grants do |t|
      t.bt_references :resource_owner,
                      target_table: :better_together_users,
                      null: false,
                      index: { name: 'index_bt_oauth_grants_on_resource_owner_id' }

      t.bt_references :application,
                      target_table: :better_together_oauth_applications,
                      null: false,
                      index: { name: 'index_bt_oauth_grants_on_application_id' }

      t.string :token, null: false
      t.integer :expires_in, null: false
      t.text :redirect_uri, null: false
      t.string :scopes, null: false, default: ''
      t.datetime :revoked_at

      t.index :token, unique: true, name: 'index_bt_oauth_grants_on_token'
    end

    create_bt_table :oauth_access_tokens do |t|
      t.bt_references :resource_owner,
                      target_table: :better_together_users,
                      null: true,
                      index: { name: 'index_bt_oauth_tokens_on_resource_owner_id' }

      t.bt_references :application,
                      target_table: :better_together_oauth_applications,
                      null: true,
                      index: { name: 'index_bt_oauth_tokens_on_application_id' }

      t.string :token, null: false
      t.string :refresh_token
      t.integer :expires_in
      t.string :scopes, null: false, default: ''
      t.datetime :revoked_at
      t.string :previous_refresh_token, null: false, default: ''

      t.index :token, unique: true, name: 'index_bt_oauth_tokens_on_token'
      t.index :refresh_token, unique: true, name: 'index_bt_oauth_tokens_on_refresh_token'
    end
  end
end
