# frozen_string_literal: true

module BetterTogether
  # Used to deny logins with expired JWT tokens
  class JwtDenylist < PlatformRecord
    include Devise::JWT::RevocationStrategies::Denylist

    self.table_name = 'better_together_jwt_denylists'
  end
end
