# frozen_string_literal: true

module BetterTogether
  module Billing
    # Pundit policy for Billing::Plan — platform stewards only.
    class PlanPolicy < ApplicationPolicy
      def index?  = platform_steward?
      def show?   = platform_steward?
      def new?    = platform_steward?
      def create? = platform_steward?
      def edit?   = platform_steward?
      def update? = platform_steward?
      def destroy? = false

      # Resolves visible plans — all plans for platform stewards, none otherwise.
      class Scope < ApplicationPolicy::Scope
        def resolve
          return scope.none unless user

          platform = ::BetterTogether::Platform.find_by(host: true)
          return scope.none unless platform && user.permitted_to?(:manage_platform, platform)

          scope.all
        end
      end

      private

      def platform_steward?
        return false unless user

        platform = ::BetterTogether::Platform.find_by(host: true)
        user.permitted_to?(:manage_platform, platform)
      end
    end
  end
end
