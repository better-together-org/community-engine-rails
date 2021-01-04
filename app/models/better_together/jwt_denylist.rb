module BetterTogether
  class JwtDenylist < ApplicationRecord
    include Devise::JWT::RevocationStrategies::Denylist
    self.table_name = 'better_together_jwt_denylists'
  end
end
