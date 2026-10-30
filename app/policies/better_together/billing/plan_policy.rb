# frozen_string_literal: true

module BetterTogether
  module Billing
    # Pundit policy for Billing::Plan. Every action is #manage_billing? (see OwnerPolicy).
    class PlanPolicy < OwnerPolicy
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

      class Scope < OwnerPolicy::Scope; end
    end
  end
end
