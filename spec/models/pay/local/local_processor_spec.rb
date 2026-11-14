# frozen_string_literal: true

require 'rails_helper'

# The processor for the ways of paying Community Engine settles itself. Pay's FakeProcessor is the precedent;
# these examples pin down where this one differs and that it behaves as a Pay processor everywhere else.
RSpec.describe 'The local Pay processor' do # rubocop:disable RSpec/DescribeClass
  describe Pay::Local::Customer do
    let(:person) { create(:better_together_person) }
    let(:platform) { create(:better_together_platform) }
    let(:customer) { person.add_payment_processor(:local, platform:) }

    it 'is a Pay customer that Pay\'s own owner API resolves by name, with our platform scoping and encryption' do
      expect(customer).to be_a(Pay::Customer)
      expect(customer).to have_attributes(type: 'Pay::Local::Customer', processor: 'local', platform_id: platform.id)
      expect(described_class.ancestors).to include(BetterTogether::Billing::PayExtensions::PlatformScoping,
                                                   BetterTogether::Billing::PayExtensions::EncryptedBillingData)
    end

    it 'is not Pay\'s fake processor, so Pay does not refuse it or treat it as a stub' do
      expect(customer.fake_processor?).to be(false)
      expect(Pay::Customer.where.not(processor: 'fake_processor')).to include(customer)
      expect { person.add_payment_processor(:local, platform:) }.not_to raise_error
    end

    it 'answers the same predicates and scopes Pay gives its own processors' do
      expect(customer).to be_local
      expect(Pay::Customer.local).to contain_exactly(customer)
    end

    it 'gets a processor id on first use, and keeps it' do
      expect(customer.api_record.processor_id).to be_present
      expect { customer.api_record }.not_to(change { customer.reload.processor_id })
    end

    describe '#charge' do
      it 'records money that settled, in the smallest unit, with how it was paid' do
        charge = customer.charge(4_500, currency: 'cad', payment_method_type: 'etransfer', metadata: { 'bt_order_id' => 'o1' })

        expect(charge).to be_a(Pay::Local::Charge)
        expect(charge).to have_attributes(amount: 4_500, currency: 'cad', payment_method_type: 'etransfer', platform_id: platform.id,
                                          processor_id: be_present)
        expect(charge.metadata).to eq('bt_order_id' => 'o1')
        expect(customer.charges).to contain_exactly(charge)
      end

      it 'is a charge to Pay: found on the owner, scoped by processor' do
        charge = customer.charge(100, currency: 'usd')

        expect(person.pay_charges).to include(charge)
        expect(Pay::Charge.local).to contain_exactly(charge)
      end

      it 'adds to what has been given back, as a Stripe charge does, and refunds the rest when no amount is given' do
        charge = customer.charge(1_000, currency: 'usd')

        charge.refund!(300)
        expect(charge.reload.amount_refunded).to eq(300)
        charge.refund!
        expect(charge.reload).to have_attributes(amount_refunded: 1_000)
        expect(charge).to be_full_refund
      end
    end

    describe '#subscribe' do
      let(:period) { { current_period_start: Time.zone.parse('2026-11-01'), current_period_end: Time.zone.parse('2026-12-01') } }

      it 'creates an active Pay subscription for the plan, over the period it is given' do
        subscription = customer.subscribe(name: 'default', plan: 'hosted', **period)

        expect(subscription).to be_a(Pay::Local::Subscription)
        expect(subscription).to have_attributes(status: 'active', processor_plan: 'hosted', quantity: 1, platform_id: platform.id,
                                                current_period_end: period[:current_period_end])
        expect(Pay::Subscription.active).to include(subscription)
        expect(Pay::Subscription.local).to contain_exactly(subscription)
      end

      it 'turns trial days into a trial end, and ignores keys that are not subscription columns' do
        subscription = customer.subscribe(name: 'default', plan: 'hosted', trial_period_days: 14, bogus: 1, **period)

        expect(subscription.trial_ends_at).to be_within(1.minute).of(14.days.from_now)
        expect(subscription).to be_on_trial
      end
    end

    describe '#add_payment_method' do
      it 'keeps a label for how the customer pays, and one default at a time' do
        first = customer.add_payment_method(nil, default: true, payment_method_type: 'cash')
        second = customer.add_payment_method(nil, default: true, payment_method_type: 'cheque')

        expect(first.reload.default).to be(false)
        expect(second.reload).to have_attributes(default: true, payment_method_type: 'cheque')
        expect(customer.reload.default_payment_method).to eq(second)
      end
    end

    it 'has nothing to sync from a processor' do
      expect(customer.sync_subscriptions).to eq([])
      expect(Pay::Local::Subscription.sync('anything')).to be_nil
      expect(Pay::Local::Charge.sync('anything')).to be_nil
    end

    it 'does not clear or take over a customer of the same person on another platform' do
      other = create(:better_together_platform)
      here = person.add_payment_processor(:local, platform:)

      there = person.add_payment_processor(:local, platform: other)

      expect(there).not_to eq(here)
      expect(here.reload.platform_id).to eq(platform.id)
    end
  end

  describe Pay::Local::Subscription do
    let(:person) { create(:better_together_person) }
    let(:platform) { create(:better_together_platform) }
    let(:customer) { person.add_payment_processor(:local, platform:) }
    let(:ends) { Time.zone.parse('2026-12-01 12:00') }
    let(:subscription) do
      customer.subscribe(name: 'default', plan: 'hosted', current_period_start: Time.zone.parse('2026-11-01'), current_period_end: ends)
    end

    it 'cancels where the paid period ends, not at the end of the month as Pay\'s fake processor does' do
      subscription.cancel

      expect(subscription.reload.ends_at).to eq(ends)
      expect(subscription).to be_on_grace_period
      expect(subscription).to be_active
      expect(Pay::Subscription.on_grace_period).to include(subscription)
    end

    it 'can be resumed during that time, and not after it has ended' do
      subscription.cancel
      subscription.resume

      expect(subscription.reload.ends_at).to be_nil

      subscription.cancel_now!
      expect { subscription.resume }.to raise_error(Pay::Error, /grace period/)
    end

    it 'ends now when cancelled now' do
      subscription.cancel_now!

      expect(subscription.reload).to have_attributes(status: 'canceled')
      expect(subscription.ends_at).to be_within(1.minute).of(Time.current)
      expect(Pay::Subscription.active).not_to include(subscription)
    end

    it 'is moved on to the next period when it is paid, and active again' do
      subscription.update!(status: 'past_due')
      next_end = Time.zone.parse('2027-01-01 12:00')

      subscription.advance!(starts_at: ends, ends_at: next_end)

      expect(subscription.reload).to have_attributes(status: 'active', current_period_start: ends, current_period_end: next_end, ends_at: nil)
      expect(Pay::Subscription.past_due).not_to include(subscription)
    end

    it 'follows Pay\'s own vocabulary for a late one, so Pay\'s scopes find it' do
      subscription.update!(status: 'past_due')
      expect(Pay::Subscription.past_due).to include(subscription)
      subscription.update!(status: 'unpaid')
      expect(Pay::Subscription.unpaid).to include(subscription)
    end

    it 'swaps plan, changes quantity, and cannot be paused' do
      subscription.swap('bigger')
      subscription.change_quantity(3)

      expect(subscription.reload).to have_attributes(processor_plan: 'bigger', quantity: 3)
      expect(subscription).not_to be_paused
      expect { subscription.pause }.to raise_error(NotImplementedError)
    end
  end
end
