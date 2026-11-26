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

      # The public catalog: shown when billing is on and the product is listed and has a price on offer.
      def catalog? = billing_available?(Current.platform)

      def catalog_show? = catalog? && record.listed? && record.active? && record.current_price.present? && purchase?

      # Buying a product, listed or not: one limited to members or subscribers is for them alone.
      def purchase?
        return false unless record.platform_id == Current.platform&.id && record.seller_id.blank?

        record.open_to?(BetterTogether::Billing::Plans::Audience.call(platform: Current.platform, person: user&.person))
      end

      # What the public catalog lists: listed, on sale, open to this person, and with a price to pay.
      class CatalogScope < ApplicationPolicy::Scope
        def resolve
          platform = Current.platform
          return scope.none unless platform && BetterTogether::Billing.enabled?(platform)

          audience = BetterTogether::Billing::Plans::Audience.call(platform:, person: agent)
          priced = BetterTogether::Billing::Price.active.select(:product_id)
          scope.for_platform(platform).sold_by_platform.listed.open_to(audience).where(id: priced).apart_from_plans
        end
      end
    end
  end
end
