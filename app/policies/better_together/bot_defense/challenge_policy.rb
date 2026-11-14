# frozen_string_literal: true

module BetterTogether
  module BotDefense
    # Policy for the bot-defense challenge endpoint.
    # Challenge issuance (show?) is intentionally public — no authentication required.
    # This policy documents that intent so that a future ResourceController refactor
    # that adds verify_authorized behaviour has the correct authorisation in place.
    class ChallengePolicy < ApplicationPolicy
      # Anyone may request a challenge token — the endpoint is deliberately unauthenticated.
      def show? = true

      class Scope < ApplicationPolicy::Scope # rubocop:todo Style/Documentation
        def resolve = scope
      end
    end
  end
end
