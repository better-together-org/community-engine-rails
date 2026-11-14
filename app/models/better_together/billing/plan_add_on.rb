# frozen_string_literal: true

module BetterTogether
  module Billing
    # One plan an add-on extends: the add-on is offered on that plan's checkout, and a buyer who holds that plan may buy the
    # add-on on its own later. An add-on with no links extends every primary plan of its platform.
    class PlanAddOn < ApplicationRecord
      include PlatformBound
      include ParentBound

      self.table_name = 'better_together_billing_plan_add_ons'

      belongs_to :plan, class_name: 'BetterTogether::Billing::Plan', inverse_of: :add_on_links
      belongs_to :add_on, class_name: 'BetterTogether::Billing::Plan', inverse_of: :target_links

      validates :add_on_id, uniqueness: { scope: :plan_id }
      validate :add_on_is_an_add_on
      validate :plan_is_primary
      validate :same_platform

      private

      def billing_parent = plan

      def add_on_is_an_add_on
        errors.add(:add_on, :must_be_an_add_on) if add_on && !add_on.add_on?
      end

      def plan_is_primary
        errors.add(:plan, :must_be_a_primary_plan) if plan&.add_on?
      end

      def same_platform
        errors.add(:plan, :platform_owner_mismatch) if plan && add_on && plan.platform_id != add_on.platform_id
      end
    end
  end
end
