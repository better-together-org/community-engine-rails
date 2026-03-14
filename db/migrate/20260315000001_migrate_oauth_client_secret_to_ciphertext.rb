# frozen_string_literal: true

class MigrateOauthClientSecretToCiphertext < ActiveRecord::Migration[7.2]
  def up
    # Rename to the ActiveRecord::Encryption convention column name.
    # AR::Encryption stores virtual attribute :oauth_client_secret in column :oauth_client_secret_ciphertext.
    rename_column :better_together_platform_connections, :oauth_client_secret, :oauth_client_secret_ciphertext

    # token_ciphertext is always NULL — token is digest-only by design. Remove dead weight.
    remove_column :better_together_federation_access_tokens, :token_ciphertext, :text
  end

  def down
    add_column :better_together_federation_access_tokens, :token_ciphertext, :text
    rename_column :better_together_platform_connections, :oauth_client_secret_ciphertext, :oauth_client_secret
  end
end
