# frozen_string_literal: true

module BetterTogether
  # OAuth2 access token for API and MCP authentication.
  # Issued by Doorkeeper, validated on each API/MCP request.
  class OauthAccessToken < ApplicationRecord
    include ::Doorkeeper::Orm::ActiveRecord::Mixins::AccessToken

    self.table_name = 'better_together_oauth_access_tokens'
  end
end
