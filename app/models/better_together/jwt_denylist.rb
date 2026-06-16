# frozen_string_literal: true

module BetterTogether
  # Used to deny logins with expired JWT tokens
  class JwtDenylist < ApplicationRecord
    include Devise::JWT::RevocationStrategies::Denylist
    include BetterTogether::PlatformScoped

    self.table_name = 'better_together_jwt_denylists'
  end
end
