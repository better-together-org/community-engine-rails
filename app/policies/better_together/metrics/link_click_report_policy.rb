# frozen_string_literal: true

module BetterTogether
  module Metrics
    # Policy for link click report access control
    class LinkClickReportPolicy < ApplicationPolicy
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

      def download?
        can_download_reports?
      end

      private

      def can_view_metrics?
        user.present? && can_view_metrics_dashboard?(platform)
      end

      def can_create_reports?
        user.present? && can_create_metrics_reports?(platform)
      end

      def can_download_reports?
        user.present? && can_download_metrics_reports?(platform)
      end

      def platform
        @platform ||= Current.platform if Current.platform&.internal?
      end
    end
  end
end
