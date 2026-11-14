# frozen_string_literal: true

# Per-platform OAuth sign-in configuration. The external Platform record is the
# provider identity; this row holds the credentials and options for one local platform.
class CreateBetterTogetherPlatformIdentityProviders < ActiveRecord::Migration[7.2]
  def change
    unless table_exists?(:better_together_platform_identity_providers)
      create_bt_table :platform_identity_providers do |t|
        t.bt_references :platform, target_table: :better_together_platforms,
                                   index: { name: 'idx_bt_platform_idps_on_platform_id' }
        t.bt_references :provider_platform, target_table: :better_together_platforms,
                                            index: { name: 'idx_bt_platform_idps_on_provider_platform_id' }
        t.string  :strategy, null: false
        t.boolean :enabled, null: false, default: true
        t.string  :client_id
        t.text    :client_secret
        t.string  :scopes
        t.jsonb   :options, null: false, default: {}
        t.integer :position, null: false, default: 0
      end
    end

    return if index_name_exists?(:better_together_platform_identity_providers, 'idx_bt_platform_idps_unique')

    add_index :better_together_platform_identity_providers, %i[platform_id provider_platform_id],
              unique: true, name: 'idx_bt_platform_idps_unique'
  end
end
