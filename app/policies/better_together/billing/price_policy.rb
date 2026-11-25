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

      # Buying one price: it is on sale and its product may be bought by this person.
      def purchase?
        record.purchasable? && ProductPolicy.new(user, record.product).purchase?
      end

      # An extra bought on its own, later: for sale to this person and a prerequisite of it is held. With a plan at checkout it is #purchase?.
      def buy_alone?
        record.extra? && purchase? && requirements(user&.person).met?
      end

      # An extra this buyer could unlock: for sale to them but a prerequisite is missing. The reason is what to show.
      def locked_reason
        record.extra? && purchase? ? requirements(user&.person).reason : nil
      end

      private

      def requirements(person)
        BetterTogether::Billing::PurchaseRequirements::Evaluate.call(dependent: record, person:)
      end
    end
  end
end
