# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Authorization for Joatu agreements
    class AgreementPolicy < ApplicationPolicy
      def index? = user.present?

      def show?
        return false unless user.present?

        participant? || permitted_to?('manage_platform')
      end

      def create?
        return false unless user.present?

        # Allow either offer or request creator to create an agreement
        participant? || permitted_to?('manage_platform')
      end

      def update?
        return false unless user.present?

        participant? || permitted_to?('manage_platform')
      end
      alias accept? update?
      alias reject? update?

      def destroy?
        return false unless user.present?

        participant? || permitted_to?('manage_platform')
      end

      def participant?
        return false unless record&.offer && record.request

        [record.offer.creator_id, record.request.creator_id].compact.include?(agent&.id)
      end

      class Scope < ApplicationPolicy::Scope
        def resolve
          return scope.none unless user.present?
          return scope.all if permitted_to?('manage_platform')

          # Agreements where the agent is either the offer or request creator
          offers = BetterTogether::Joatu::Offer.arel_table
          requests = BetterTogether::Joatu::Request.arel_table

          join = scope.joins(:offer, :request)
          join.where(
            offers[:creator_id].eq(agent&.id).or(requests[:creator_id].eq(agent&.id))
          )
        end
      end
    end
  end
end
