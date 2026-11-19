# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Content
    RSpec.describe PlanButtonBlock do
      it 'is a subclass of Content::Block' do
        expect(described_class.superclass).to eq(BetterTogether::Content::Block)
      end

      it 'is content_addable' do
        expect(described_class.content_addable?).to be true
      end

      it 'permits every attribute it stores' do
        expect(described_class.extra_permitted_attributes).to include(*(described_class.storext_definitions.keys - BetterTogether::Content::Block.storext_definitions.keys).map(&:to_sym))
      end

      it 'defaults to a card with no plan' do
        expect(described_class.new).to have_attributes(display_as: 'card', plan_id: '', plan: nil)
      end

      it 'only displays as a card or a button' do
        expect(described_class.new(display_as: 'banner')).not_to be_valid
        expect(described_class.new(display_as: 'button')).to be_valid
      end

      it 'finds its plan on its own platform' do
        plan = create(:better_together_billing_plan)

        expect(described_class.new(plan_id: plan.id, platform_id: plan.platform_id).plan).to eq(plan)
      end

      it 'does not find, and rejects, a plan of another platform' do
        plan = create(:better_together_billing_plan)
        other = create(:better_together_platform)
        block = described_class.new(plan_id: plan.id, platform_id: other.id)

        expect(block.plan).to be_nil
        expect(block).not_to be_valid
        expect(block.errors).to include(:plan_id)
      end
    end
  end
end
