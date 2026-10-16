# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::SyncPlanJob do
  include_context 'with clean billing processors'

  let(:adapter) { BetterTogether::Billing::FakeAdapter.new(capabilities: %i[plan_sync]) }
  let(:plan) { create('better_together/billing/plan') }

  before { BetterTogether::Billing.register_processor(:fake, -> { adapter }) }

  it 'pushes the plan through its processor adapter' do
    described_class.perform_now(plan.id)

    expect(adapter.calls).to include([:sync_plan, plan.id])
  end

  it 'ignores a plan that no longer exists' do
    expect { described_class.perform_now(SecureRandom.uuid) }.not_to raise_error
    expect(adapter.calls).to be_empty
  end

  it 'does nothing when the processor cannot sync plans' do
    BetterTogether.clear_adapters!(BetterTogether::Billing::ADAPTER_GROUP)
    BetterTogether::Billing.register_processor(:fake, -> { BetterTogether::Billing::FakeAdapter.new })

    expect { described_class.perform_now(plan.id) }.not_to raise_error
  end

  it 'does nothing when the processor is no longer installed' do
    BetterTogether.clear_adapters!(BetterTogether::Billing::ADAPTER_GROUP)

    expect { described_class.perform_now(plan.id) }.not_to raise_error
  end
end
