# frozen_string_literal: true

module BetterTogether
  class GuestAccessPolicy < PlatformInvitationPolicy
    class Scope < PlatformInvitationPolicy::Scope # rubocop:todo Style/Documentation
      def resolve
        scope.all
      end
    end
  end
end
