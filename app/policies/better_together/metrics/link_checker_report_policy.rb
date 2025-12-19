# frozen_string_literal: true

module BetterTogether
  module Metrics
    # Policy for link checker report access control
    class LinkCheckerReportPolicy < ApplicationPolicy
      def index?
        can_view_metrics?
      end

      def show?
        can_view_metrics?
      end

      def create?
        can_create_reports?
      end

      def destroy?
        can_create_reports?
      end

      private

      def can_view_metrics?
        return false unless user

        user.permitted_to?(:view_metrics_dashboard, platform) ||
          user.permitted_to?(:manage_platform, platform)
      end

      def can_create_reports?
        return false unless user

        user.permitted_to?(:create_metrics_reports, platform) ||
          user.permitted_to?(:manage_platform, platform)
      end

      def platform
        @platform ||= Platform.find_by(host: true)
      end
    end
  end
end
