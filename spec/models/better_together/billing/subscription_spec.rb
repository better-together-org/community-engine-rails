# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Subscription do
  subject(:subscription) { build('better_together/billing/subscription') }

  it 'is valid with the factory defaults' do
    expect(subscription).to be_valid
  end

  it 'identifies activeish statuses' do
    expect(subscription.activeish?).to be(true)

    subscription.pay_subscription.status = 'canceled'

    expect(subscription.activeish?).to be(false)
  end

  describe '#access_active?' do
    it 'is true when activeish' do
      expect(subscription.access_active?).to be(true)
    end

    it 'is true when lapsed but still within the grace period' do
      persisted = create('better_together/billing/subscription')
      persisted.pay_subscription.update!(status: 'canceled')
      persisted.sync_lapse_state!

      expect(persisted.access_active?).to be(true)
    end

    it 'is false when lapsed and the grace period has expired' do
      persisted = create('better_together/billing/subscription')
      persisted.pay_subscription.update!(status: 'canceled')
      persisted.sync_lapse_state!

      travel_to(8.days.from_now) { expect(persisted.access_active?).to be(false) }
    end
  end

  it 'delegates status to pay_subscription' do
    expect(subscription.status).to eq(subscription.pay_subscription.status)
  end

  it 'exposes the processor from the pay customer' do
    expect(subscription.processor).to eq('stripe')
  end

  describe '#status_badge_class' do
    {
      'active' => 'text-bg-success',
      'trialing' => 'text-bg-success',
      'past_due' => 'text-bg-warning',
      'unpaid' => 'text-bg-warning',
      'canceled' => 'text-bg-danger',
      'incomplete_expired' => 'text-bg-danger',
      'incomplete' => 'text-bg-secondary',
      'paused' => 'text-bg-secondary'
    }.each do |status, expected_class|
      it "returns #{expected_class} for status #{status}" do
        subscription.pay_subscription.status = status

        expect(subscription.status_badge_class).to eq(expected_class)
      end
    end
  end

  it 'persists portal access failures in metadata' do
    subscription = create('better_together/billing/subscription')

    subscription.record_portal_access_failure!(message: 'Stripe portal outage')

    expect(subscription.reload.portal_access_issue?).to be(true)
    expect(subscription.last_portal_error_message).to eq('Stripe portal outage')
  end

  describe 'app-owned grace period' do
    let(:persisted_subscription) { create('better_together/billing/subscription') }

    around do |example|
      original = ENV.fetch('BT_BILLING_HOSTED_ACCESS_GRACE_PERIOD_DAYS', nil)
      ENV['BT_BILLING_HOSTED_ACCESS_GRACE_PERIOD_DAYS'] = '7'
      example.run
    ensure
      ENV['BT_BILLING_HOSTED_ACCESS_GRACE_PERIOD_DAYS'] = original
    end

    describe '#sync_lapse_state!' do
      it 'records a lapsed_at timestamp when the subscription is not activeish' do
        persisted_subscription.pay_subscription.update!(status: 'canceled')

        persisted_subscription.sync_lapse_state!

        expect(persisted_subscription.reload.lapsed_at).to be_present
        expect(persisted_subscription).to be_in_grace_period
      end

      it 'does not reset the grace-period clock on repeated syncs while still lapsed' do
        persisted_subscription.pay_subscription.update!(status: 'canceled')
        persisted_subscription.sync_lapse_state!
        first_lapsed_at = persisted_subscription.reload.lapsed_at

        travel_to(1.day.from_now) { persisted_subscription.sync_lapse_state! }

        expect(persisted_subscription.reload.lapsed_at).to eq(first_lapsed_at)
      end

      it 'clears the lapse marker once the subscription recovers to activeish' do
        persisted_subscription.pay_subscription.update!(status: 'canceled')
        persisted_subscription.sync_lapse_state!
        expect(persisted_subscription.reload.lapsed_at).to be_present

        persisted_subscription.pay_subscription.update!(status: 'active')
        persisted_subscription.sync_lapse_state!

        expect(persisted_subscription.reload.lapsed_at).to be_nil
        expect(persisted_subscription).not_to be_in_grace_period
      end

      it 'clears a previously-sent grace notice marker on recovery' do
        persisted_subscription.pay_subscription.update!(status: 'canceled')
        persisted_subscription.sync_lapse_state!
        persisted_subscription.record_grace_notice_sent!

        persisted_subscription.pay_subscription.update!(status: 'active')
        persisted_subscription.sync_lapse_state!

        expect(persisted_subscription.reload.grace_notice_sent?).to be(false)
      end
    end

    describe '#grace_period_expired?' do
      it 'is true once the configured grace period has elapsed since the lapse' do
        persisted_subscription.pay_subscription.update!(status: 'canceled')
        persisted_subscription.sync_lapse_state!

        travel_to(8.days.from_now) do
          expect(persisted_subscription).to be_grace_period_expired
          expect(persisted_subscription).not_to be_in_grace_period
        end
      end
    end

    describe '.possibly_lapsed' do
      it 'includes only subscriptions that have ever been marked lapsed' do
        persisted_subscription.pay_subscription.update!(status: 'canceled')
        persisted_subscription.sync_lapse_state!
        never_lapsed = create('better_together/billing/subscription')

        expect(described_class.possibly_lapsed).to include(persisted_subscription)
        expect(described_class.possibly_lapsed).not_to include(never_lapsed)
      end
    end
  end
end
