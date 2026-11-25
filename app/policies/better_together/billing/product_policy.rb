# frozen_string_literal: true

module BetterTogether
  module Billing
    # Pundit policy for Billing::Product. Every action is #manage_billing? (see OwnerPolicy).
    class ProductPolicy < OwnerPolicy
      def index?  = manage_billing?
      def show?   = manage_billing?
      def new?    = manage_billing?
      def create? = manage_billing?
      def edit?   = manage_billing?
      def update? = manage_billing?
      def destroy? = false
    end
  end
end
