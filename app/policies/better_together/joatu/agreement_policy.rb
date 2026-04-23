# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Authorization for Joatu agreements
    class AgreementPolicy < ApplicationPolicy
      def index? = user.present?

      def show?
        return false unless user.present?

        return can_view_connection_agreement? if connection_request_agreement?

        scope_allows_record?
      end

      def create?
        return false unless user.present?

        return can_manage_network_connections? if connection_request_agreement?

        participant? || can_manage_joatu?
      end

      def update?
        return false unless user.present?

        return can_approve_network_connections? if connection_request_agreement?

        participant? || can_manage_joatu?
      end
      alias accept? update?
      alias cancel? update?
      alias reject? update?
      alias fulfill? update?

      def destroy?
        return false unless user.present?

        return can_manage_network_connections? if connection_request_agreement?

        participant? || can_manage_joatu?
      end

      def participant?
        return false unless record.present?

        record.participant_for?(agent)
      end

      class Scope < ApplicationPolicy::Scope # rubocop:todo Style/Documentation
        def resolve # rubocop:todo Metrics/AbcSize
          return scope.none unless user.present?
          return scope.all if can_manage_joatu?
          return scope.all if can_manage_network_connections? && connection_request_agreement_scope?

          public_records = scope.where(privacy: 'public')

          # Agreements where the agent is either the offer or request creator
          offers = BetterTogether::Joatu::Offer.arel_table
          requests = BetterTogether::Joatu::Request.arel_table

          join = scope.joins(:offer, :request)
          participant_records = join.where(
            offers[:creator_id].eq(agent&.id).or(requests[:creator_id].eq(agent&.id))
          )

          public_records.or(scope.where(id: participant_records.select(:id)))
        end

        private

        def can_manage_joatu?
          permitted_to?('manage_joatu')
        end

        def can_manage_network_connections?
          permitted_to?('manage_network_connections')
        end

        def connection_request_agreement_scope?
          scope.joins(:request).where(better_together_joatu_requests: { type: 'BetterTogether::Joatu::ConnectionRequest' })
          true
        rescue StandardError
          false
        end
      end

      private

      def connection_request_agreement?
        record.request.is_a?(BetterTogether::Joatu::ConnectionRequest)
      end

      def can_manage_joatu?
        permitted_to?('manage_joatu')
      end

      def can_manage_network_connections?
        permitted_to?('manage_network_connections')
      end

      def can_approve_network_connections?
        permitted_to?('approve_network_connections')
      end

      def can_view_connection_agreement?
        can_manage_network_connections? || can_approve_network_connections? || participant?
      end

      def scope_allows_record?
        self.class::Scope.new(user, record.class).resolve.where(id: record.id).exists?
      end
    end
  end
end
