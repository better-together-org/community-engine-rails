# frozen_string_literal: true

module BetterTogether
  module Billing
    # Pundit policy for Billing::Promotion: only a steward who may manage the platform's billing makes,
    # lists and switches promotions on and off. People redeem a code through their own credit page.
    class PromotionPolicy < OwnerPolicy
      def index? = manage_billing?
      def new? = manage_billing?
      def create? = manage_billing?
      def activate? = manage_billing?
      def deactivate? = manage_billing?
      def show? = false
      def update? = false
      def destroy? = false
    end
  end
end
