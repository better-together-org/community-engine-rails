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

      # The public catalog: anyone may read it while billing is on. What they see is the CatalogScope.
      def catalog? = billing_available?(Current.platform)

      # One listed plan in the catalog: it is listed and active, and the person qualifies for its audience.
      def catalog_show? = catalog? && record.listed? && record.active? && !record.add_on? && purchase?

      # A plan offered from a page (a plan block): active, and the person qualifies, listed in the catalog or not.
      def offer? = catalog? && record.active? && !record.add_on? && purchase?

      # Buying a plan, listed or not: a plan limited to members or subscribers is for them alone, so a link to it gets no one else in.
      def purchase?
        return false unless record.platform_id == Current.platform&.id && record.seller_id.blank?

        record.open_to?(audience_for(user))
      end

      # An add-on bought on its own, later: the buyer qualifies for its audience and holds a plan it extends (any primary plan of the
      # platform when it names none). Buying one with a plan at checkout is #purchase?.
      def buy_alone?
        return false unless record.add_on? && purchase?

        held = BetterTogether::Billing::Plans::Holdings.call(platform: Current.platform, person: user&.person)
        targets = record.target_links.pluck(:plan_id)
        targets.empty? ? held.any? : held.intersect?(targets)
      end

      class Scope < OwnerPolicy::Scope; end

      # The plans the catalog shows this person: the platform's listed plans, and of the limited ones only those they qualify for.
      class CatalogScope < ApplicationPolicy::Scope
        def resolve
          platform = Current.platform
          return scope.none unless platform && BetterTogether::Billing.enabled?(platform)

          audience = BetterTogether::Billing::Plans::Audience.call(platform:, person: agent)
          scope.for_platform(platform).sold_by_platform.primary.listed.open_to(audience)
        end
      end

      private

      def audience_for(user)
        BetterTogether::Billing::Plans::Audience.call(platform: Current.platform, person: user&.person)
      end
    end
  end
end
