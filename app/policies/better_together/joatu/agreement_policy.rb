# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Authorization for Joatu agreements
    class AgreementPolicy < ApplicationPolicy
      def index? = user.present?

      def show?
        return false unless user.present?

        participant? || can_manage_joatu?
      end

      def create?
        return false unless user.present?

        participant? || can_manage_joatu?
      end

      def update?
        return false unless user.present?

        participant? || can_manage_joatu?
      end
      alias accept? update?
      alias reject? update?

      def destroy?
        return false unless user.present?

        participant? || can_manage_joatu?
      end

      def participant?
        return false unless record&.offer && record.request

        [record.offer.creator_id, record.request.creator_id].compact.include?(agent&.id)
      end

      class Scope < ApplicationPolicy::Scope # rubocop:todo Style/Documentation
        def resolve # rubocop:todo Metrics/AbcSize
          return scope.none unless user.present?
          return scope.all if can_manage_joatu?

          # Agreements where the agent is either the offer or request creator
          offers = BetterTogether::Joatu::Offer.arel_table
          requests = BetterTogether::Joatu::Request.arel_table

          join = scope.joins(:offer, :request)
          join.where(
            offers[:creator_id].eq(agent&.id).or(requests[:creator_id].eq(agent&.id))
          )
        end

        private

        def can_manage_joatu?
          permitted_to?('manage_joatu')
        end
      end

      private

      def can_manage_joatu?
        permitted_to?('manage_joatu')
      end
    end
  end
end
