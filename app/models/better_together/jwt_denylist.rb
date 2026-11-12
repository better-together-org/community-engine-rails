# frozen_string_literal: true

module BetterTogether
  # Used to deny logins with expired JWT tokens
  class JwtDenylist < PlatformRecord
    include Devise::JWT::RevocationStrategies::Denylist

    self.table_name = 'better_together_jwt_denylists'

    # A token is valid only on the platform that issued it (`plt` claim, set by User#jwt_payload).
    # Tokens with no platform claim (issued before this check) are refused; they live one hour.
    class << self
      alias denylisted? jwt_revoked?

      def jwt_revoked?(payload, user)
        current = ::Current.platform&.id
        return true if current.blank? || payload['plt'].to_s != current.to_s

        denylisted?(payload, user)
      end
    end
  end
end
