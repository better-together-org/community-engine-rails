# frozen_string_literal: true

class MigrateOauthClientSecretToCiphertext < ActiveRecord::Migration[7.2]
  def up
    # AR::Encryption stores the encrypted JSON blob in the column named after the virtual attribute.
    # `encrypts :oauth_client_secret` uses column `oauth_client_secret` (same name, no _ciphertext suffix).
    # No column rename is needed — AR::Encryption writes into the existing column in-place.

    # token_ciphertext is always NULL — token is digest-only by design. Remove dead weight.
    remove_column :better_together_federation_access_tokens, :token_ciphertext, :text
  end

  def down
    add_column :better_together_federation_access_tokens, :token_ciphertext, :text
  end
end
