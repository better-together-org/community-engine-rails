# frozen_string_literal: true

class CreateBetterTogetherFederationAccessTokens < ActiveRecord::Migration[7.1]
  def change
    create_table :better_together_federation_access_tokens, id: :uuid do |t|
      t.references :platform_connection,
                   null: false,
                   foreign_key: { to_table: :better_together_platform_connections },
                   type: :uuid,
                   index: { name: 'index_bt_federation_access_tokens_on_platform_connection_id' }
      t.text :token_ciphertext, null: false
      t.string :token_digest, null: false
      t.text :scopes, null: false, default: ''
      t.datetime :expires_at, null: false
      t.datetime :revoked_at
      t.datetime :last_used_at

      t.timestamps
    end

    add_index :better_together_federation_access_tokens,
              :token_digest,
              unique: true,
              name: 'index_bt_federation_access_tokens_on_token_digest'
  end
end
