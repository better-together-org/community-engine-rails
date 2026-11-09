# frozen_string_literal: true

module BetterTogether
  module Billing
    # Pundit policy for Billing::PlanGrant (what a plan includes). Only a steward who may manage the platform's
    # billing, and only for the platform's own plans: a seller's plan cannot give roles or quotas on the platform.
    class PlanGrantPolicy < OwnerPolicy
      def create? = platform_plan? && manage_billing?
      def destroy? = platform_plan? && manage_billing?
      def index? = false
      def show? = false
      def update? = false

      private

      def platform_plan? = record.respond_to?(:plan) && record.plan.present? && record.plan.seller_id.blank?
    end
  end
end
