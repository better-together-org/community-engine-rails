# frozen_string_literal: true

module BetterTogether
  module BreakGlass
    # Ends a grant at once. The requester, the grantee and a holder of the sealed permission may revoke.
    class Revoke
      def self.call(...)
        new(...).call
      end

      def initialize(grant:, actor:)
        @grant = grant
        @actor = actor
      end

      def call
        raise NotAuthorized unless allowed?
        return @grant if @grant.revoked?

        BreakGlassGrant.transaction do
          @grant.update!(status: 'revoked', revoked_at: Time.current)
          @grant.events.create!(event_type: 'revoked', actor: @actor, platform: @grant.platform,
                                detail: { revoked_at: @grant.revoked_at })
        end
        @grant
      end

      private

      def allowed?
        return false if @actor.blank?

        [@grant.requested_by_id, @grant.grantee_id].include?(@actor.id) ||
          @actor.permitted_to?(Request::PERMISSION, @grant.platform)
      end
    end
  end
end
