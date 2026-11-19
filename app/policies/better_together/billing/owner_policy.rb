# frozen_string_literal: true

module BetterTogether
  module Billing
    # Shared rules for the billing screens a platform's stewards use.
    #
    # Every action asks one question, #manage_billing?(owner): is billing available for the
    # owner, and may this person manage billing for it? The owner is a platform today. When
    # communities can manage their own billing, only this method gains a community branch
    # (with its own `manage_community_billing` permission); callers do not change.
    class OwnerPolicy < ApplicationPolicy
      # Billing must be available for the owner and the person must manage that platform.
      # Never defaults to the host platform: an owner that cannot be named is refused.
      #
      # Only a platform can be an owner today. A record sold by a community or person belongs
      # to that seller, so a platform steward cannot manage it through the platform's
      # screens; the community branch arrives with community-managed billing.
      def manage_billing?(owner = owner_for_record)
        return false unless user && owner.is_a?(BetterTogether::Platform)

        billing_available?(owner) && user.permitted_to?(:manage_platform, owner)
      end

      # What the person may see: the records the current platform itself owns, and only if
      # they may manage its billing.
      class Scope < ApplicationPolicy::Scope
        def resolve
          platform = Current.platform
          return scope.none unless user && platform

          allowed = available?(platform) && user.permitted_to?(:manage_platform, platform)
          allowed ? scope.for_platform(platform).sold_by_platform : scope.none
        end

        private

        # Plans need a working method; the settings that turn the first one on do not.
        def available?(platform) = BetterTogether::Billing.enabled?(platform)
      end

      private

      def billing_available?(owner) = BetterTogether::Billing.enabled?(owner)

      # The seller when a seller owns the record, otherwise its platform.
      def owner_for_record
        return record.seller if record.respond_to?(:seller_id) && record.seller_id.present?

        (record.platform if record.respond_to?(:platform)) || Current.platform
      end
    end
  end
end
