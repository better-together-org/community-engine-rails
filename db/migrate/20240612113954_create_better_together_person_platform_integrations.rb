# frozen_string_literal: true

# This table is used to store the relationship between a person and an external platform
class CreateBetterTogetherPersonPlatformIntegrations < ActiveRecord::Migration[7.1]
  def change # rubocop:todo Metrics/MethodLength
    create_bt_table :person_platform_integrations do |t|
      t.string :provider, limit: 50, null: false, default: ''
      t.string :uid, limit: 50, null: false, default: ''

      t.string :name
      t.string :handle
      t.string :profile_url
      t.string :image_url

      t.string :access_token
      t.string :access_token_secret
      t.string :refresh_token
      t.datetime :expires_at
      t.jsonb :auth

      t.bt_references :person, index: { name: 'bt_person_platform_conections_by_person' }
      t.bt_references :platform, index: { name: 'bt_person_platform_conections_by_platform' }
      t.bt_references :user, index: { name: 'bt_person_platform_conections_by_user' }
    end
  end
end
