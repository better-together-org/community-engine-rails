# frozen_string_literal: true

# Adds a BCrypt digest column for inbound OAuth client secret verification.
#
# The existing AR-encrypted `oauth_client_secret` remains for outbound use
# (pull services need to recover the plaintext to authenticate to peers).
# The new `oauth_client_secret_digest` stores a BCrypt hash used only for
# inbound verification — authenticate_oauth_secret no longer needs to decrypt.
#
# Existing rows are populated in a data migration below: the current plaintext
# (or AR-decrypted value) is hashed at migration time so all connections are
# immediately verifiable via the new path.
class AddOauthClientSecretDigestToBetterTogetherPlatformConnections < ActiveRecord::Migration[7.2]
  # Use an anonymous model to avoid coupling to app code (model renames,
  # encryption config changes, or eager-loading issues won't break deploys).
  class PlatformConnectionMigration < ActiveRecord::Base
    self.table_name = 'better_together_platform_connections'
  end

  def up
    add_column :better_together_platform_connections,
               :oauth_client_secret_digest, :string

    require 'bcrypt'

    # Backfill: generate BCrypt digests for all existing platform connections
    # that already have a secret stored.
    PlatformConnectionMigration.find_each do |conn|
      next if conn.oauth_client_secret.blank?

      conn.update_column(
        :oauth_client_secret_digest,
        BCrypt::Password.create(conn.oauth_client_secret)
      )
    end
  end

  def down
    remove_column :better_together_platform_connections, :oauth_client_secret_digest
  end
end
