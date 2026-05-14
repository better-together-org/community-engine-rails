# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Plan do
  include ActiveJob::TestHelper

  subject(:plan) { build('better_together/billing/plan') }

  it 'is valid with the factory defaults' do
    expect(plan).to be_valid
  end

  it 'requires a supported billing interval' do
    plan.billing_interval = 'week'

    expect(plan).not_to be_valid
    expect(plan.errors[:billing_interval]).to be_present
  end

  it 'reports recurring plans correctly' do
    expect(plan.recurring?).to be(true)

    plan.billing_interval = 'one_time'

    expect(plan.recurring?).to be(false)
  end

  it 'treats recurring plans as launch-ready for hosted billing' do
    expect(plan.launch_ready_for_hosted_billing?).to be(true)

    plan.billing_interval = 'one_time'

    expect(plan.launch_ready_for_hosted_billing?).to be(false)
  end

  it 'prefers participant-facing metadata for summaries and benefits' do
    expect(plan.participant_summary).to eq('Supports hosted participation and stewardship for this Better Together space.')
    expect(plan.participant_benefits).to eq(['Hosted access', 'Ongoing stewardship support'])
    expect(plan.beneficiary_label).to eq('Hosted access')
    expect(plan.hosted_access_level).to eq('Standard')
    expect(plan.support_tier).to eq('Community')
  end

  it 'falls back to description and owner types when participant metadata is missing' do
    plan.metadata = {}
    plan.description = 'Supports a community-hosted space.'

    expect(plan.participant_summary).to eq('Supports a community-hosted space.')
    expect(plan.participant_benefits).to eq([])
    expect(plan.beneficiary_label).to eq('Hosted access')
  end

  describe 'uniqueness validation' do
    it 'rejects a duplicate stripe_price_id' do
      create('better_together/billing/plan', stripe_price_id: 'price_unique_one')

      duplicate = build('better_together/billing/plan', stripe_price_id: 'price_unique_one')

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:stripe_price_id]).to be_present
    end
  end

  describe 'price field immutability' do
    subject(:persisted_plan) do
      create('better_together/billing/plan',
             amount_cents: 5000,
             currency: 'CAD',
             billing_interval: 'month',
             stripe_price_id: 'price_imm_test')
    end

    it 'prevents changing amount_cents after stripe_price_id is linked' do
      persisted_plan.amount_cents = 9999

      expect(persisted_plan).not_to be_valid
      expect(persisted_plan.errors[:amount_cents]).to be_present
    end

    it 'prevents changing currency after stripe_price_id is linked' do
      persisted_plan.currency = 'USD'

      expect(persisted_plan).not_to be_valid
      expect(persisted_plan.errors[:currency]).to be_present
    end

    it 'prevents changing billing_interval after stripe_price_id is linked' do
      persisted_plan.billing_interval = 'year'

      expect(persisted_plan).not_to be_valid
      expect(persisted_plan.errors[:billing_interval]).to be_present
    end

    it 'allows changing name even after stripe_price_id is linked' do
      persisted_plan.name = 'Updated Name'

      expect(persisted_plan).to be_valid
    end

    it 'allows changing active even after stripe_price_id is linked' do
      persisted_plan.active = false

      expect(persisted_plan).to be_valid
    end
  end

  describe '.permitted_attributes' do
    it 'includes mutable plan fields' do
      expect(described_class.permitted_attributes).to include(:name, :description, :active)
    end

    it 'excludes price-defining fields' do
      flat = described_class.permitted_attributes.flatten
      expect(flat).not_to include(:amount_cents, :currency, :billing_interval, :stripe_price_id)
    end
  end

  describe '.permitted_attributes_for_create' do
    it 'includes price-defining fields' do
      flat = described_class.permitted_attributes_for_create.flatten
      expect(flat).to include(:amount_cents, :currency, :billing_interval, :stripe_price_id)
    end
  end

  describe '#active_subscription_count' do
    subject(:persisted_plan) { create('better_together/billing/plan') }

    let(:community) { create(:better_together_community) }
    let(:pay_customer) do
      Pay::Customer.create!(owner: community, processor: 'stripe', processor_id: 'cus_count_test')
    end

    it 'returns 0 when there are no active subscriptions' do
      expect(persisted_plan.active_subscription_count).to eq(0)
    end

    it 'counts active Pay subscriptions linked to this plan' do
      pay_sub = Pay::Subscription.create!(
        customer: pay_customer,
        name: 'default',
        processor_id: 'sub_count_active',
        processor_plan: persisted_plan.stripe_price_id,
        status: 'active',
        current_period_start: Time.current.beginning_of_day,
        current_period_end: 1.month.from_now.beginning_of_day
      )
      BetterTogether::Billing::Subscription.create!(
        pay_subscription: pay_sub,
        billing_plan: persisted_plan
      )

      expect(persisted_plan.active_subscription_count).to eq(1)
    end
  end

  describe 'after_commit :enqueue_stripe_sync!' do
    it 'enqueues SyncPlanToStripeJob when a plan is created' do
      expect do
        create('better_together/billing/plan')
      end.to have_enqueued_job(BetterTogether::Billing::SyncPlanToStripeJob)
    end

    it 'enqueues SyncPlanToStripeJob when a plan is updated' do
      persisted_plan = create('better_together/billing/plan')

      expect do
        persisted_plan.update!(name: 'Updated Name')
      end.to have_enqueued_job(BetterTogether::Billing::SyncPlanToStripeJob)
        .with(persisted_plan.id)
    end

    it 'does not enqueue when stripe_price_id is blank' do
      skip 'stripe_price_id is NOT NULL in schema; guard applies only if future schema change allows null'
    end
  end
end
