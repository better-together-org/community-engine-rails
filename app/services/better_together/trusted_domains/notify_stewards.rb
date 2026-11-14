# frozen_string_literal: true

module BetterTogether
  module TrustedDomains
    # Delivers an in-app notification about a trusted domain audit event to the platform's active stewards.
    class NotifyStewards
      STEWARD_ROLES = %w[platform_steward platform_manager platform_administrator].freeze

      def self.call(...)
        new(...).call
      end

      def initialize(event:)
        @event = event
      end

      def call
        recipients = stewards.reject { |person| person.id == @event.subject_id }
        return if recipients.empty?

        BetterTogether::TrustedDomainGrantNotifier.with(record: @event).deliver_later(recipients)
      end

      private

      def stewards
        BetterTogether::PersonPlatformMembership.joins(:role).includes(:member).active
                                                .where(joinable: @event.platform)
                                                .where(better_together_roles: { identifier: STEWARD_ROLES })
                                                .map(&:member).compact.uniq(&:id)
      end
    end
  end
end
