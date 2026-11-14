# frozen_string_literal: true

module BetterTogether
  module Billing
    # Pundit policy for Billing::SubscriptionTerm (a subscription).
    #
    # The payer sees and manages their own subscriptions (cancel, resume, accept changed terms). A steward who
    # may manage the platform's billing sees the platform's subscribers and can waive a period, give more
    # time, cancel, or move one to the current price. Nobody creates, edits or removes one through a screen:
    # a subscription is made by paying for it.
    class SubscriptionTermPolicy < OwnerPolicy
      # The signed-in person's own subscriptions list.
      def own? = user.present?
      def show? = payer?
      def cancel? = payer?
      def resume? = payer?
      def accept_agreements? = payer?
      def change_plan? = payer?
      def change_method? = payer?

      # Stewards.
      def index? = manage_billing?
      def subscriber? = manage_billing?
      def waive? = manage_billing?
      def extend_grace? = manage_billing?
      def steward_cancel? = manage_billing?
      def move_to_current_price? = manage_billing?

      def create? = false
      def update? = false
      def destroy? = false

      private

      def payer?
        person = user.respond_to?(:person) ? user.person : nil
        person.present? && record.respond_to?(:payer) && record.payer == person
      end
    end
  end
end
