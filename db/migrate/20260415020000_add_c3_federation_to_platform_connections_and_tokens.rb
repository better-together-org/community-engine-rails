# frozen_string_literal: true

class AddC3FederationToPlatformConnectionsAndTokens < ActiveRecord::Migration[7.2]
  def change
    # -- PlatformConnection: C3 exchange opt-in flags (stored in :settings jsonb) -----------
    # No schema change needed — store_attributes :settings is already a jsonb column.
    # The allow_c3_exchange and c3_exchange_rate attributes are added to the model
    # and default to false / '1.0' respectively.

    # -- C3::Token: origin tracking for federated tokens -----------------------------------
    unless column_exists?(:better_together_c3_tokens, :origin_platform_id)
      add_column :better_together_c3_tokens, :origin_platform_id, :uuid, null: true
      add_foreign_key :better_together_c3_tokens, :better_together_platforms,
                      column: :origin_platform_id, on_delete: :nullify
      add_index :better_together_c3_tokens, :origin_platform_id,
                name: 'idx_bt_c3_tokens_origin_platform',
                where: 'origin_platform_id IS NOT NULL'
    end

    return if column_exists?(:better_together_c3_tokens, :federated)

    add_column :better_together_c3_tokens, :federated, :boolean, null: false, default: false
  end
end
