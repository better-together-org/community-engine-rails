# frozen_string_literal: true

# Creates the federation access tokens table.
# Tokens are issued to remote platforms for authenticated cross-instance API calls.
# token_digest stores a secure hash of the token — the raw token is never persisted.
class CreateBetterTogetherFederationAccessTokens < ActiveRecord::Migration[7.2]
  def change
    create_bt_table :federation_access_tokens do |t|
      t.bt_references :platform_connection, target_table: :better_together_platform_connections,
                                            index: { name: 'index_bt_federation_access_tokens_on_platform_connection_id' }
      t.string   :token_digest, null: false
      t.text     :scopes,       null: false, default: ''
      t.datetime :expires_at,   null: false
      t.datetime :revoked_at
      t.datetime :last_used_at
    end

    add_index :better_together_federation_access_tokens, :token_digest,
              unique: true, name: 'index_bt_federation_access_tokens_on_token_digest'

    add_foreign_key :better_together_federation_access_tokens, :better_together_platform_connections,
                    column: :platform_connection_id
  end
end
