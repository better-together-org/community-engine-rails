# frozen_string_literal: true

module BetterTogether
  module Billing
    # Pundit policy for Billing::Price. A price is made and archived, never edited or destroyed.
    class PricePolicy < OwnerPolicy
      def index?  = manage_billing?
      def show?   = manage_billing?
      def new?    = manage_billing?
      def create? = manage_billing?
      def archive? = manage_billing?
      def edit? = false
      def update? = false
      def destroy? = false
    end
  end
end
