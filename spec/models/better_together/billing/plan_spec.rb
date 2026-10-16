# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Plan do
  include ActiveJob::TestHelper

  subject(:plan) { build('better_together/billing/plan') }

  include_context 'with clean billing processors'

  let(:adapter) { BetterTogether::Billing::FakeAdapter.new(capabilities: %i[checkout plan_sync]) }

  before { BetterTogether::Billing.register_processor(:fake, -> { adapter }) }

  it 'is valid with the factory defaults' do
    expect(plan).to be_valid
  end

  it 'requires a supported billing interval' do
    plan.billing_interval = 'week'

    expect(plan).not_to be_valid
    expect(plan.errors[:billing_interval]).to be_present
  end

  it 'reports recurring plans and hosted-billing readiness' do
    expect(plan.recurring?).to be(true)
    expect(plan.launch_ready_for_hosted_billing?).to be(true)

    plan.billing_interval = 'one_time'

    expect(plan.recurring?).to be(false)
    expect(plan.launch_ready_for_hosted_billing?).to be(false)
  end

  describe 'participant-facing metadata' do
    it 'prefers metadata for summary, benefits and labels' do
      expect(plan.participant_summary).to eq('Supports hosted participation and stewardship for this Better Together space.')
      expect(plan.participant_benefits).to eq(['Hosted access', 'Ongoing stewardship support'])
      expect(plan.hosted_access_level).to eq('Standard')
      expect(plan.support_tier).to eq('Community')
    end

    it 'falls back to the description when metadata is missing' do
      plan.metadata = {}
      plan.description = 'Supports a community-hosted space.'

      expect(plan.participant_summary).to eq('Supports a community-hosted space.')
      expect(plan.participant_benefits).to eq([])
    end
  end

  describe 'currency' do
    it 'accepts every supported code and rejects others' do
      described_class::SUPPORTED_CURRENCY_CODES.each do |code|
        plan.currency = code
        expect(plan).to be_valid, "expected #{code} to be valid"
      end
      plan.currency = 'ZZZ'
      expect(plan).not_to be_valid
    end

    it 'has no default currency' do
      expect(described_class.new.currency).to be_nil
    end
  end

  describe 'processor linkage' do
    it 'requires a registered processor when created' do
      plan.processor = 'ghost'

      expect(plan).not_to be_valid
      expect(plan.errors.details[:processor]).to include(a_hash_including(error: :not_installed))
    end

    it 'requires a snake_case processor and a price id' do
      plan.processor = 'Fake Co'
      plan.processor_price_id = ''

      expect(plan).not_to be_valid
      expect(plan.errors[:processor_price_id]).to be_present
    end

    it 'rejects a duplicate price id at the same processor but allows it at another' do
      create('better_together/billing/plan', processor_price_id: 'price_one')

      expect(build('better_together/billing/plan', processor_price_id: 'price_one')).not_to be_valid
      BetterTogether::Billing.register_processor(:other, -> { BetterTogether::Billing::FakeAdapter.new })
      expect(build('better_together/billing/plan', processor: 'other', processor_price_id: 'price_one')).to be_valid
    end

    it 'rejects a price the processor does not know (cross-account link)' do
      plan.processor_price_id = 'price_missing_1'

      expect(plan).not_to be_valid
      expect(plan.errors.details[:processor_price_id]).to include(a_hash_including(error: :not_found_at_processor))
    end

    it 'fails closed when the price lookup itself fails' do
      plan.processor_price_id = 'price_boom_1'

      expect(plan).not_to be_valid
      expect(plan.errors.details[:processor_price_id]).to include(a_hash_including(error: :lookup_failed))
    end

    it 'skips price verification for a processor without plan sync' do
      BetterTogether.clear_adapters!(BetterTogether::Billing::ADAPTER_GROUP)
      BetterTogether::Billing.register_processor(:fake, -> { BetterTogether::Billing::FakeAdapter.new })
      plan.processor_price_id = 'price_missing_1'

      expect(plan).to be_valid
    end
  end

  describe 'price field immutability' do
    subject(:persisted_plan) { create('better_together/billing/plan', amount_cents: 5000, currency: 'USD', billing_interval: 'month') }

    { amount_cents: 9999, currency: 'EUR', billing_interval: 'year' }.each do |field, value|
      it "prevents changing #{field} once a processor price is linked" do
        persisted_plan.public_send(:"#{field}=", value)

        expect(persisted_plan).not_to be_valid
        expect(persisted_plan.errors.details[field]).to include(a_hash_including(error: :immutable_after_processor_link))
      end
    end

    it 'allows changing name and active' do
      persisted_plan.assign_attributes(name: 'Updated', active: false)

      expect(persisted_plan).to be_valid
    end
  end

  describe '.permitted_attributes' do
    it 'excludes price-defining fields on update and includes them on create' do
      update_keys = described_class.permitted_attributes.flatten
      create_keys = described_class.permitted_attributes_for_create.flatten

      expect(update_keys).to include(:name, :description, :active)
      expect(update_keys).not_to include(:amount_cents, :currency, :billing_interval, :processor, :processor_price_id)
      expect(create_keys).to include(:amount_cents, :currency, :billing_interval, :processor, :processor_price_id)
    end
  end

  describe 'pricing tiers' do
    it 'defaults to standard and recognises solidarity tiers' do
      expect(plan.pricing_tier).to eq('standard')
      expect(plan).not_to be_solidarity_tier

      plan.metadata = { 'pricing_tier' => 'solidarity_small', 'solidarity_description' => 'For small co-ops' }

      expect(plan).to be_solidarity_tier
      expect(plan.solidarity_description).to eq('For small co-ops')
    end

    it 'reports an unknown tier with a translatable error' do
      plan.metadata = { 'pricing_tier' => 'platinum' }

      expect(plan).not_to be_valid
      expect(plan.errors.details[:base]).to include(a_hash_including(error: :invalid_pricing_tier, tier: 'platinum'))
      expect(plan.errors.full_messages.to_sentence).to include('platinum')
    end
  end

  describe '#eligible_billable_owner_types' do
    it 'defaults to community and person' do
      expect(plan.eligible_billable_owner_types).to eq(described_class::DEFAULT_ELIGIBLE_OWNER_TYPES)
    end

    it 'drops names that are not billable models and falls back to the default' do
      plan.metadata = { 'eligible_billable_owner_types' => ['Kernel', 'Nope::Missing'] }

      expect(plan.eligible_billable_owner_types).to eq(described_class::DEFAULT_ELIGIBLE_OWNER_TYPES)
    end

    it 'keeps registered billable models' do
      stub_const('BillableThing', Class.new { include BetterTogether::Billing::Billable })
      plan.metadata = { 'eligible_billable_owner_types' => ['BillableThing'] }

      expect(plan.eligible_billable_owner_types).to eq(['BillableThing'])
    end
  end

  describe 'processor sync on commit' do
    it 'enqueues a sync job on create and update when the processor supports plan sync' do
      saved = nil
      expect { saved = create('better_together/billing/plan') }.to have_enqueued_job(BetterTogether::Billing::SyncPlanJob)
      expect { saved.update!(name: 'Renamed') }.to have_enqueued_job(BetterTogether::Billing::SyncPlanJob).with(saved.id)
    end

    it 'does not enqueue when the change came from the processor (transient guard)' do
      saved = create('better_together/billing/plan')
      saved.skip_processor_sync = true

      expect { saved.update!(name: 'From processor') }.not_to have_enqueued_job(BetterTogether::Billing::SyncPlanJob)
    end

    it 'keeps syncing later admin edits after a processor-originated save' do
      saved = create('better_together/billing/plan')
      saved.skip_processor_sync = true
      saved.update!(name: 'From processor')

      expect { described_class.find(saved.id).update!(name: 'Admin edit') }.to have_enqueued_job(BetterTogether::Billing::SyncPlanJob)
    end

    it 'does not enqueue when the processor has no plan sync capability' do
      BetterTogether.clear_adapters!(BetterTogether::Billing::ADAPTER_GROUP)
      BetterTogether::Billing.register_processor(:fake, -> { BetterTogether::Billing::FakeAdapter.new })

      expect { create('better_together/billing/plan') }.not_to have_enqueued_job(BetterTogether::Billing::SyncPlanJob)
    end
  end
end
