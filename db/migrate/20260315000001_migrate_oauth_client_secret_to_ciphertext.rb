# frozen_string_literal: true

# AR::Encryption convention documentation:
# `encrypts :oauth_client_secret` stores the encrypted JSON blob in a column named
# `oauth_client_secret` (same name — NOT `oauth_client_secret_ciphertext`).
# This is different from lockbox (_ciphertext suffix) and attr_encrypted (encrypted_ prefix).
#
# token_ciphertext was dropped from this migration because create_bt_table for
# federation_access_tokens no longer creates that column — tokens are digest-only by design.
class MigrateOauthClientSecretToCiphertext < ActiveRecord::Migration[7.2]
  def change
    # no-op: schema corrections moved into originating create_bt_table migrations
  end
end
