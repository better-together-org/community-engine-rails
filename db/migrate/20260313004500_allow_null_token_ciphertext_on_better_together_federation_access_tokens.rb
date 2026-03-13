# frozen_string_literal: true

class AllowNullTokenCiphertextOnBetterTogetherFederationAccessTokens < ActiveRecord::Migration[7.1]
  def change
    change_column_null :better_together_federation_access_tokens, :token_ciphertext, true
  end
end
