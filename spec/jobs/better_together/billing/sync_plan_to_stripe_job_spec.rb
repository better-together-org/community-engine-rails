# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::SyncPlanToStripeJob do
  include ActiveJob::TestHelper

  describe 'queueing' do
    it 'uses the default queue' do
      expect(described_class.new.queue_name).to eq('default')
    end
  end

  describe '#perform' do
    let!(:plan) { create(:better_together_billing_plan) }

    let(:sync_service) { instance_double(BetterTogether::Billing::StripePlanSync) }
    let(:sync_result) do
      BetterTogether::Billing::StripePlanSync::Result.new(
        synced: true,
        plan: plan,
        stripe_product_id: 'prod_123',
        stripe_price_id: plan.stripe_price_id,
        reason: :synced
      )
    end

    before do
      allow(BetterTogether::Billing::StripePlanSync).to receive(:new).and_return(sync_service)
      allow(sync_service).to receive(:call).and_return(sync_result)
    end

    it 'calls StripePlanSync with the plan' do
      described_class.perform_now(plan.id)

      expect(sync_service).to have_received(:call).with(plan: plan)
    end

    it 'does nothing when the plan is not found' do
      expect { described_class.perform_now('nonexistent-plan-id') }.not_to raise_error

      expect(sync_service).not_to have_received(:call)
    end
  end
end
