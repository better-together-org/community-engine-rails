# frozen_string_literal: true

module BetterTogether
  module Billing
    # Who may deal with hosted billing. The hosted platform's steward accepts the host's agreements for it; the host's steward
    # reviews every hosted platform and may suspend one. Neither needs billing to be on yet: this is how it gets switched on.
    class HostedBillingPolicy < ApplicationPolicy
      # The steward of a hosted (non-host) platform, on that platform.
      def show? = hosted_steward?
      def accept? = hosted_steward?

      # The steward of the host platform.
      def index? = host_steward?
      def suspend? = host_steward?
      def resume? = host_steward?

      private

      def platform = Current.platform

      def requested? = BetterTogether::Billing::Configuration.requested? && BetterTogether::Billing::Configuration.ready?

      def hosted_steward?
        user.present? && requested? && platform.present? && !platform.host? && user.permitted_to?(:manage_platform, platform)
      end

      def host_steward?
        user.present? && requested? && platform.present? && platform.host? && user.permitted_to?(:manage_platform, platform)
      end
    end
  end
end
