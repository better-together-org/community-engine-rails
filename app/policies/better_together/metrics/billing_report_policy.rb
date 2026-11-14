# frozen_string_literal: true

module BetterTogether
  module Metrics
    # Who may see, make, download and delete billing reports and the billing charts. It asks the same metrics
    # permissions as every other report and, because the figures are money, also that the person manages the platform's
    # billing, so an analytics viewer who cannot see sales never can through a report either.
    class BillingReportPolicy < ApplicationPolicy
      def index? = can_view_metrics_dashboard?(platform) && manages_billing?
      def show? = index?
      def create? = can_create_metrics_reports?(platform) && manages_billing?
      def destroy? = create? && on_this_platform?
      def download? = can_download_metrics_reports?(platform) && manages_billing? && on_this_platform?

      private

      def manages_billing?
        user.present? && platform.present? && BetterTogether::Billing.configurable?(platform) && user.permitted_to?(:manage_platform, platform)
      end

      # A report of another platform is never reachable, whatever its id.
      def on_this_platform? = !record.respond_to?(:platform_id) || record.platform_id == platform&.id

      def platform = @platform ||= Current.platform || Current.host_platform
    end
  end
end
