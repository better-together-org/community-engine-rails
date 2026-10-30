# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Plan do
  include ActiveJob::TestHelper

  include_context 'with clean billing processors'

  let!(:host_platform) { configure_host_platform }
  let(:other_platform) { create(:better_together_platform) }
  let(:rules) { nil }
  let(:adapter) { BetterTogether::Billing::FakeAdapter.new(capabilities: %i[checkout plan_sync lookups], rules:) }

  before { BetterTogether::Billing.register_processor(:fake, -> { adapter }) }

  def new_plan(**attrs)
    host_platform.billing_plans.build({ identifier: "plan-#{SecureRandom.hex(4)}", name: 'Hosted', billing_interval: 'month',
                                        amount_cents: 4500, currency: 'USD', processor: 'fake' }.merge(attrs))
  end

  # Helpers are defined at the top of the file: this repo's describe/context extension
  # instance_evals nested blocks, which would turn a nested `def` into a class method.
  def link_plan(price_id, **attrs)
    new_plan(link_existing: true, processor_price_id: price_id, amount_cents: 1, currency: 'EUR', **attrs)
  end

  context 'when every platform has a processor context' do
    before do
      allow(BetterTogether::Billing::Configuration).to receive(:context_for) do |platform, processor|
        BetterTogether::Billing::ProcessorContext.new(platform:, processor:)
      end
    end

    it_behaves_like 'a platform-bound billing record' do
      def build_record(platform:) = new_plan.tap { |plan| plan.platform = platform }
    end
  end

  it 'is reached through its platform and cannot be exported as a seed' do
    plan = create(:better_together_billing_plan)

    expect(host_platform.billing_plans).to include(plan)
    expect(plan).not_to respond_to(:export_as_seed)
  end

  describe 'defaults' do
    it 'is valid with the factory defaults' do
      expect(build(:better_together_billing_plan)).to be_valid
    end

    it 'has no default currency' do
      expect(described_class.new.currency).to be_nil
    end

    it 'requires a supported billing interval' do
      plan = new_plan(billing_interval: 'week')

      expect(plan).not_to be_valid
      expect(plan.errors[:billing_interval]).to be_present
    end

    it 'accepts every supported currency and rejects others' do
      described_class::SUPPORTED_CURRENCY_CODES.each { |code| expect(new_plan(currency: code)).to be_valid, "expected #{code}" }
      expect(new_plan(currency: 'ZZZ')).not_to be_valid
    end
  end

  describe 'creating a plan in the processor' do
    subject(:plan) { new_plan }

    it 'needs no price id: the processor creates the product and price' do
      expect(plan).to be_valid
      expect(plan.processor_price_id).to be_nil
    end

    it 'waits for its first push and enqueues it' do
      expect { plan.save! }.to have_enqueued_job(BetterTogether::Billing::SyncPlanJob)

      expect(plan.reload).to have_attributes(sync_status: 'pending', manages_processor_product: true, processor_price_id: nil)
    end

    it 'does not manage the product it was attached to, because it did not create it' do
      plan = new_plan(processor_product_id: 'prod_pro')

      plan.valid?

      expect(plan.manages_processor_product).to be(false)
    end

    it 'cannot be created for a processor that is not installed' do
      plan = new_plan(processor: 'ghost')

      expect(plan).not_to be_valid
      expect(plan.errors.details[:processor]).to include(a_hash_including(error: :not_installed))
    end

    it 'cannot be created on a platform that has no billing configured for the processor' do
      plan = other_platform.billing_plans.build(identifier: 'p', name: 'P', amount_cents: 1, currency: 'USD', processor: 'fake')

      expect(plan).not_to be_valid
      expect(plan.errors.details[:processor]).to include(a_hash_including(error: :not_configured))
    end
  end

  describe 'linking a price that already exists' do
    it 'copies the amount, currency, interval and product from the processor, whatever was typed' do
      adapter.prices['price_yearly'] = BetterTogether::Billing::PriceInfo.new(
        price_id: 'price_yearly', product_id: 'prod_pro', amount_cents: 99_000, currency: 'cad', interval: 'year'
      )
      plan = link_plan('price_yearly', billing_interval: 'month')

      expect(plan).to be_valid
      expect(plan).to have_attributes(amount_cents: 99_000, currency: 'CAD', billing_interval: 'year', processor_product_id: 'prod_pro',
                                      manages_processor_product: false, sync_status: 'synced')
    end

    it 'is already synced, so nothing is pushed' do
      expect { link_plan('price_ok').save! }.not_to have_enqueued_job(BetterTogether::Billing::SyncPlanJob)
    end

    it 'rejects a price the processor does not know' do
      plan = link_plan('price_missing_1')

      expect(plan).not_to be_valid
      expect(plan.errors.details[:processor_price_id]).to include(a_hash_including(error: :not_found_at_processor))
    end

    it 'rejects an archived price' do
      plan = link_plan('price_inactive_1')

      expect(plan).not_to be_valid
      expect(plan.errors.details[:processor_price_id]).to include(a_hash_including(error: :price_inactive))
    end

    it 'fails closed when the processor cannot be reached' do
      plan = link_plan('price_boom_1')

      expect(plan).not_to be_valid
      expect(plan.errors.details[:processor_price_id]).to include(a_hash_including(error: :lookup_failed))
    end

    it 'logs and reports an unexpected error instead of hiding it' do
      allow(adapter).to receive(:fetch_price).and_raise(NoMethodError, 'bug')
      allow(BetterTogether).to receive(:report_error)
      allow(Rails.logger).to receive(:error)

      expect(link_plan('price_ok')).not_to be_valid

      expect(BetterTogether).to have_received(:report_error).with(an_instance_of(NoMethodError), anything)
      expect(Rails.logger).to have_received(:error).with(/price lookup failed/)
    end

    it 'looks up any price id on a new plan, even if the form did not say "link"' do
      plan = new_plan(processor_price_id: 'price_missing_1')

      expect(plan).not_to be_valid
      expect(plan.errors.details[:processor_price_id]).to include(a_hash_including(error: :not_found_at_processor))
    end

    it 'rejects a price id already used by another plan at the same processor' do
      create(:better_together_billing_plan, processor_price_id: 'price_taken')

      expect(link_plan('price_taken')).not_to be_valid
    end
  end

  describe 'a processor that cannot push plans' do
    let(:adapter) { BetterTogether::Billing::FakeAdapter.new(capabilities: %i[checkout]) }

    it 'requires the price id, because nothing will create it' do
      plan = new_plan

      expect(plan).not_to be_valid
      expect(plan.errors[:processor_price_id]).to be_present
    end

    it 'records the plan as synced and enqueues nothing' do
      plan = new_plan(processor_price_id: 'price_manual')

      expect { plan.save! }.not_to have_enqueued_job(BetterTogether::Billing::SyncPlanJob)
      expect(plan.reload.sync_status).to eq('synced')
    end
  end

  describe 'identifiers and products across platforms' do
    it 'keeps an identifier unique within a platform, not across platforms' do
      create(:better_together_billing_plan, identifier: 'hosted', platform: other_platform)

      expect(new_plan(identifier: 'hosted')).to be_valid

      create(:better_together_billing_plan, identifier: 'hosted')
      expect(new_plan(identifier: 'hosted')).not_to be_valid
    end

    it 'lets several plans of one platform share a product (a monthly and a yearly price)' do
      create(:better_together_billing_plan, processor_product_id: 'prod_pro')

      expect(new_plan(processor_product_id: 'prod_pro')).to be_valid
    end

    it 'refuses a product that another platform already uses' do
      create(:better_together_billing_plan, processor_product_id: 'prod_pro', platform: other_platform)
      plan = new_plan(processor_product_id: 'prod_pro')

      expect(plan).not_to be_valid
      expect(plan.errors.details[:processor_product_id]).to include(a_hash_including(error: :used_by_another_platform))
    end
  end

  describe 'fields the processor fixes at creation' do
    subject(:plan) { create(:better_together_billing_plan, amount_cents: 5000, currency: 'USD', billing_interval: 'month') }

    %i[amount_cents currency billing_interval processor_product_id processor_price_id].each do |field|
      it "locks #{field} once the plan is linked" do
        plan.public_send(:"#{field}=",
                         { amount_cents: 9999, currency: 'EUR', billing_interval: 'year', processor_product_id: 'prod_x',
                           processor_price_id: 'price_x' }[field])

        expect(plan).not_to be_valid
        expect(plan.errors.details[field]).to include(a_hash_including(error: :immutable_after_processor_link))
        expect(plan).to be_locked_field(field)
      end
    end

    it 'locks the processor too' do
      plan.processor = 'other'

      expect(plan).not_to be_valid
      expect(plan.errors.details[:processor]).to include(a_hash_including(error: :immutable_after_processor_link))
    end

    it 'leaves the name, description and active flag editable when the adapter says they are updatable' do
      plan.assign_attributes(name: 'Renamed', description: 'New words', active: false)

      expect(plan).to be_valid
    end

    it 'leaves a descriptive field editable when the adapter says nothing about it' do
      adapter.instance_variable_set(:@rules, {})

      expect(plan).not_to be_locked_field(:name)
      expect(plan).to be_locked_field(:amount_cents)
    end

    context 'when the adapter declares a descriptive field create-only' do
      let(:rules) { { name: :create_only, amount_cents: :create_only } }

      it 'locks it as well' do
        plan.name = 'Renamed'

        expect(plan).not_to be_valid
        expect(plan.errors.details[:name]).to include(a_hash_including(error: :immutable_after_processor_link))
      end
    end

    context 'when the adapter says the processor will change the amount' do
      let(:rules) { { amount_cents: :updatable } }

      it 'does not lock it' do
        plan.amount_cents = 9999

        expect(plan).to be_valid
        expect(plan).not_to be_locked_field(:amount_cents)
      end
    end

    it 'does not lock anything before a price exists' do
      unlinked = create(:better_together_billing_plan, :unlinked)
      unlinked.assign_attributes(amount_cents: 1, currency: 'CAD', billing_interval: 'year')

      expect(unlinked).to be_valid
    end

    it 'permits only what can still change' do
      linked_keys = plan.permitted_update_attributes.grep_v(Hash)
      unlinked_keys = create(:better_together_billing_plan, :unlinked).permitted_update_attributes.grep_v(Hash)

      expect(linked_keys).to contain_exactly(:name, :description, :active)
      expect(unlinked_keys).to include(:amount_cents, :currency, :billing_interval)
    end
  end

  describe 'pushing changes to the processor' do
    let!(:plan) { create(:better_together_billing_plan) }

    it 'enqueues a push when the name, description or active flag changes' do
      expect { plan.update!(name: 'Renamed') }.to have_enqueued_job(BetterTogether::Billing::SyncPlanJob).with(plan.id)
      expect { plan.update!(description: 'More words') }.to have_enqueued_job(BetterTogether::Billing::SyncPlanJob)
      expect { plan.update!(active: false) }.to have_enqueued_job(BetterTogether::Billing::SyncPlanJob)
    end

    it 'does not push when only local metadata changes' do
      expect { plan.update!(metadata: plan.metadata.merge('support_tier' => 'Premium')) }
        .not_to have_enqueued_job(BetterTogether::Billing::SyncPlanJob)
    end

    it 'does not push a change that came from the processor' do
      plan.skip_processor_sync = true

      expect { plan.update!(name: 'From processor') }.not_to have_enqueued_job(BetterTogether::Billing::SyncPlanJob)
    end

    it 'keeps pushing later edits after a processor-originated save' do
      plan.skip_processor_sync = true
      plan.update!(name: 'From processor')

      expect { described_class.find(plan.id).update!(name: 'Admin edit') }.to have_enqueued_job(BetterTogether::Billing::SyncPlanJob)
    end

    it 'never pushes for a processor that cannot sync plans' do
      adapter.instance_variable_set(:@capabilities, %i[checkout])

      expect { plan.update!(name: 'Renamed') }.not_to have_enqueued_job(BetterTogether::Billing::SyncPlanJob)
    end
  end

  describe 'storing what the processor did' do
    let!(:plan) { create(:better_together_billing_plan, :unlinked) }
    let(:result) do
      BetterTogether::Billing::PlanSyncResult.new(
        product_id: 'prod_new', price: BetterTogether::Billing::PriceInfo.new(price_id: 'price_new', product_id: 'prod_new')
      )
    end

    it 'records the ids and marks the plan synced, without triggering another push' do
      expect { plan.apply_sync_result!(result) }.not_to have_enqueued_job(BetterTogether::Billing::SyncPlanJob)

      expect(plan.reload).to have_attributes(processor_product_id: 'prod_new', processor_price_id: 'price_new', sync_status: 'synced',
                                             sync_error: nil)
      expect(plan.synced_to_processor_at).to be_present
      expect(plan).to be_linked
    end

    it 'keeps the ids the processor returned even if something unrelated about the plan is invalid' do
      plan.update_columns(metadata: { 'pricing_tier' => 'platinum' }) # rubocop:disable Rails/SkipsModelValidations

      expect { plan.apply_sync_result!(result) }.not_to raise_error
      expect(plan.reload.processor_price_id).to eq('price_new')
    end

    it 'records a failure as a short code and can start again' do
      plan.record_sync_failure!('processor_unavailable')
      expect(plan.reload).to have_attributes(sync_status: 'failed', sync_error: 'processor_unavailable')
      expect(plan).to be_sync_failed

      plan.restart_sync!
      expect(plan.reload).to have_attributes(sync_status: 'pending', sync_error: nil)
    end

    it 'derives a different idempotency key for creating and for updating' do
      expect(plan.sync_idempotency_key).to eq("bt-plan-create-#{plan.id}")

      plan.apply_sync_result!(result)

      expect(plan.reload.sync_idempotency_key).to eq("bt-plan-update-#{plan.id}-#{plan.lock_version}")
    end
  end

  describe 'eligible owner types' do
    it 'defaults to community and person' do
      expect(new_plan.eligible_billable_owner_types).to eq(described_class::DEFAULT_ELIGIBLE_OWNER_TYPES)
    end

    it 'accepts the defaults and any class that opted in to billing' do
      BetterTogether::Billing::Billable.model_names << 'Host::Organisation'
      plan = new_plan(metadata: { 'eligible_billable_owner_types' => ['BetterTogether::Person', 'Host::Organisation'] })

      expect(plan).to be_valid
      expect(plan.eligible_billable_owner_types).to eq(['BetterTogether::Person', 'Host::Organisation'])
    ensure
      BetterTogether::Billing::Billable.model_names.delete('Host::Organisation')
    end

    it 'rejects a name that is not billable instead of quietly falling back to the defaults' do
      plan = new_plan(metadata: { 'eligible_billable_owner_types' => ['Kernel', 'Nope::Missing'] })

      expect(plan).not_to be_valid
      expect(plan.errors.details[:base]).to include(a_hash_including(error: :unknown_owner_types))
    end

    it 'never resolves a configured name to a constant' do
      expect_any_instance_of(String).not_to receive(:safe_constantize) # rubocop:disable RSpec/AnyInstance
      expect_any_instance_of(String).not_to receive(:constantize) # rubocop:disable RSpec/AnyInstance

      new_plan(metadata: { 'eligible_billable_owner_types' => ['Kernel'] }).valid?
    end
  end

  describe 'participant-facing metadata' do
    let(:plan) { build(:better_together_billing_plan) }

    it 'prefers metadata for summary, benefits and labels' do
      expect(plan.participant_summary).to eq('Supports hosted participation and stewardship for this Better Together space.')
      expect(plan.participant_benefits).to eq(['Hosted access', 'Ongoing stewardship support'])
      expect(plan.hosted_access_level).to eq('Standard')
    end

    it 'falls back to the description, then to translated text, when metadata is missing' do
      plan.metadata = {}
      plan.description = 'Supports a community-hosted space.'
      expect(plan.participant_summary).to eq('Supports a community-hosted space.')

      plan.description = nil
      expect(plan.participant_summary).to eq(I18n.t('better_together.billing.plan_defaults.recurring_participant_summary'))
    end

    it 'defaults to the standard pricing tier and recognises solidarity tiers' do
      expect(plan.pricing_tier).to eq('standard')
      plan.metadata = { 'pricing_tier' => 'solidarity_small' }
      expect(plan).to be_solidarity_tier
    end

    it 'reports an unknown tier with a translatable error' do
      plan.metadata = { 'pricing_tier' => 'platinum' }

      expect(plan).not_to be_valid
      expect(plan.errors.details[:base]).to include(a_hash_including(error: :invalid_pricing_tier, tier: 'platinum'))
    end
  end
end
