# frozen_string_literal: true

module BetterTogether
  module Billing
    # Authorizes creating a sponsorship offer (as its sponsor), accepting/
    # declining an offer (as its beneficiary), and ending an active
    # sponsorship (either party). Token-based public review (#show) is gated
    # by token possession in the controller, not this policy. Namespaced
    # under Billing:: to match Pundit's convention-based lookup for
    # BetterTogether::Billing::Sponsorship.
    class SponsorshipPolicy < ApplicationPolicy
      def create?
        user.present? && actor_matches?(record.sponsor)
      end

      def accept?
        user.present? && record.status_pending? && actor_matches?(record.beneficiary)
      end

      def decline?
        user.present? && record.status_pending? && actor_matches?(record.beneficiary)
      end

      def end?
        user.present? && %w[accepted active].include?(record.status) &&
          (actor_matches?(record.sponsor) || actor_matches?(record.beneficiary))
      end

      private

      def actor_matches?(entity)
        return false if entity.blank? || agent.blank?
        return entity == agent if entity.is_a?(BetterTogether::Person)
        return Pundit.policy!(user, entity).update? if entity.is_a?(BetterTogether::Community)

        false
      end
    end
  end
end
