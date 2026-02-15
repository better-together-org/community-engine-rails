# frozen_string_literal: true

module BetterTogether
  # OAuth2 access grant for authorization_code flow.
  # Short-lived grant exchanged for an access token.
  class OauthAccessGrant < ApplicationRecord
    include ::Doorkeeper::Orm::ActiveRecord::Mixins::AccessGrant

    self.table_name = 'better_together_oauth_access_grants'
  end
end
