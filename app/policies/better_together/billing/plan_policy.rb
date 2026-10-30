# frozen_string_literal: true

module BetterTogether
  module Billing
    # Pundit policy for Billing::Plan.
    #
    # Every action asks one question, #manage_billing?(owner): is billing switched on for
    # the owner, and may this person manage billing for it? The owner is a platform today.
    # When communities can manage their own plans, only this method gains a community
    # branch (with its own `manage_community_billing` permission); callers do not change.
    class PlanPolicy < ApplicationPolicy
      def index?  = manage_billing?
      def show?   = manage_billing?
      def new?    = manage_billing?
      def create? = manage_billing?
      def edit?   = manage_billing?
      def update? = manage_billing?
      def sync?   = manage_billing?
      def snapshot? = manage_billing?
      def lookup? = manage_billing?
      def destroy? = false

      # Billing must be on for the owner (a flag, a configured identity and a processor
      # with a context for that platform) and the person must manage that platform. Never
      # defaults to the host platform: an owner that cannot be named is refused.
      def manage_billing?(owner = owner_platform)
        return false unless user && owner.present?

        BetterTogether::Billing.enabled?(owner) && user.permitted_to?(:manage_platform, owner)
      end

      # Plans visible to the acting person: the current platform's, and only if they may
      # manage its billing.
      class Scope < ApplicationPolicy::Scope
        def resolve
          platform = Current.platform
          return scope.none unless user && platform

          allowed = BetterTogether::Billing.enabled?(platform) && user.permitted_to?(:manage_platform, platform)
          allowed ? scope.for_platform(platform) : scope.none
        end
      end

      private

      def owner_platform
        (record.platform if record.respond_to?(:platform)) || Current.platform
      end
    end
  end
end
