# frozen_string_literal: true

# This migration was generated when federation_access_tokens briefly had a `token_ciphertext`
# column. The create_bt_table migration was subsequently updated to use digest-only storage
# (token_digest), so `token_ciphertext` no longer exists. Kept as a no-op to preserve
# migration history and avoid checksum conflicts in existing deployments.
class AllowNullTokenCiphertextOnBetterTogetherFederationAccessTokens < ActiveRecord::Migration[7.2]
  def change
    return unless column_exists?(:better_together_federation_access_tokens, :token_ciphertext)

    change_column_null :better_together_federation_access_tokens, :token_ciphertext, true
  end
end
