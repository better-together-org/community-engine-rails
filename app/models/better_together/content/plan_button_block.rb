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

      def self.extra_permitted_attributes
        super + %i[plan_id display_as]
      end

      def plan
        return if plan_id.blank?

        BetterTogether::Billing::Plan.find_by(id: plan_id)
      end
    end
  end
end
