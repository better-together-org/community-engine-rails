# frozen_string_literal: true

# Add indexes on expires_at and revoked_at for federation tables.
# These columns are used in current_active scopes on every request; without
# indexes, every scope evaluation does a full table scan.
class AddExpiryIndexesToFederationTables < ActiveRecord::Migration[7.1]
  def change
    # FederationAccessToken — hot-path: every inbound M2M token lookup
    add_index :better_together_federation_access_tokens, :expires_at,
              name: 'index_bt_federation_access_tokens_on_expires_at'
    add_index :better_together_federation_access_tokens, :revoked_at,
              name: 'index_bt_federation_access_tokens_on_revoked_at'

    # PersonAccessGrant — queried on every linked-seed export
    add_index :better_together_person_access_grants, :expires_at,
              name: 'index_bt_person_access_grants_on_expires_at'
    add_index :better_together_person_access_grants, :revoked_at,
              name: 'index_bt_person_access_grants_on_revoked_at'

    # PersonLink — queried when resolving federation identity
    add_index :better_together_person_links, :revoked_at,
              name: 'index_bt_person_links_on_revoked_at'
  end
end
