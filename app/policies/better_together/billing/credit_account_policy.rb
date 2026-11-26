# frozen_string_literal: true

module BetterTogether
  module Billing
    # Pundit policy for Billing::CreditAccount.
    #
    # A holder sees their own credit. A steward who may manage billing for the platform sees the platform's
    # accounts and gives credit, through the same #manage_billing? question as plans and sales. Credit is the
    # platform's own money, so only the platform's stewards are involved, never a community's or a seller's.
    class CreditAccountPolicy < OwnerPolicy
      # Any signed-in person may look at their own credit page.
      def own? = user.present?

      def index? = manage_billing?
      def show? = manage_billing?
      # A steward gives credit to someone else (the service refuses to a steward themselves).
      def grant? = manage_billing?
      def create? = false
      def update? = false
      def destroy? = false
    end
  end
end
