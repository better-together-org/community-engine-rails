# frozen_string_literal: true

module BetterTogether
  module Content
    # One billing plan as a call to buy it: a card (name, price, button) or just the button.
    # Shown only to people the plan is offered to; to everyone else the block renders nothing.
    class PlanButtonBlock < Block
      DISPLAYS = %w[card button].freeze

      store_attributes :content_data do
        plan_id String, default: ''
        display_as String, default: 'card'
      end

      validates :display_as, inclusion: { in: DISPLAYS }
      validate :plan_belongs_to_platform

      def self.extra_permitted_attributes
        super + %i[plan_id display_as]
      end

      def plan
        return if plan_id.blank?

        BetterTogether::Billing::Plan.where(platform_id:).find_by(id: plan_id)
      end

      private

      # A block may only point at a plan of its own platform, never one from another tenant.
      def plan_belongs_to_platform
        return if plan_id.blank? || plan.present?

        errors.add(:plan_id, :invalid)
      end
    end
  end
end
