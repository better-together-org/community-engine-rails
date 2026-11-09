# frozen_string_literal: true

require 'rails_helper'

# Cancelling, resuming, covering a period, giving more time, repricing and adopting a subscription.
RSpec.describe 'Managing subscriptions' do # rubocop:disable RSpec/DescribeClass
  include_context 'with subscription fixtures'

  let(:term) { start_subscription }
  let(:subscriptions) { BetterTogether::Billing::Subscriptions }
  let(:period_end) { Time.utc(2027, 2, 28, 15) }

  def subscription = term.reload.pay_subscription

  describe BetterTogether::Billing::Subscriptions::Cancel do
    it 'ends the subscription where the paid period ends, taking nothing back' do
      described_class.call(term:)

      expect(subscription).to have_attributes(status: 'active', ends_at: period_end)
      expect(subscription).to be_active
      expect(subscription).to be_on_grace_period
    end

    it 'cancels the unpaid renewal invoice with it, and its period lapses' do
      period = generate_renewal(term, at: Time.utc(2027, 2, 20))

      described_class.call(term:)

      expect(period.order.reload).to be_cancelled
      expect(period.reload).to be_lapsed
    end

    it 'ends it now when asked to' do
      described_class.call(term:, now: true)

      expect(subscription.status).to eq('canceled')
      expect(subscription.ends_at).to be_present
    end

    it 'tells the payer and the stewards once' do
      clear_notices
      deliver_now { 2.times { described_class.call(term:, by: steward) } }

      expect(kinds_for(buyer).count('subscription_canceled')).to eq(1)
    end

    it 'does nothing to a subscription that has already ended' do
      described_class.call(term:, now: true)

      expect { described_class.call(term:) }.not_to(change { subscription.reload.updated_at })
    end
  end

  describe BetterTogether::Billing::Subscriptions::Resume do
    it 'undoes a cancellation while the paid period still runs' do
      BetterTogether::Billing::Subscriptions::Cancel.call(term:)

      described_class.call(term:)

      expect(subscription).to have_attributes(status: 'active', ends_at: nil)
    end

    it 'refuses a subscription that was not cancelled, and one that has ended' do
      expect { described_class.call(term:) }.to raise_error(described_class::Refused)

      BetterTogether::Billing::Subscriptions::Cancel.call(term:, now: true)
      expect { described_class.call(term:) }.to raise_error(described_class::Refused)
    end
  end

  describe BetterTogether::Billing::Subscriptions::Waive do
    it 'covers the next period without payment, cancels its invoice, and moves the subscription on' do
      period = generate_renewal(term, at: Time.utc(2027, 2, 20))

      described_class.call(term:, by: steward)

      expect(period.reload).to have_attributes(status: 'waived')
      expect(period.order.reload).to be_cancelled
      expect(subscription).to have_attributes(status: 'active', current_period_end: Time.utc(2027, 3, 31, 15))
    end

    it 'makes the period when no invoice has been made yet' do
      expect(described_class.call(term:)).to have_attributes(sequence: 1, status: 'waived')
      expect(subscription.current_period_end).to eq(Time.utc(2027, 3, 31, 15))
    end

    it 'brings a subscription that is past due back to active' do
      advance(term, at: period_end + 1.day)
      expect(subscription.status).to eq('past_due')

      described_class.call(term:)

      expect(subscription).to have_attributes(status: 'active')
      expect(term.reload.grace_ends_at).to be_nil
    end

    it 'refuses a subscription that has ended' do
      BetterTogether::Billing::Subscriptions::Cancel.call(term:, now: true)

      expect { described_class.call(term:) }.to raise_error(described_class::Refused)
    end
  end

  describe BetterTogether::Billing::Subscriptions::ExtendGrace do
    it 'gives a past due subscription more days before it lapses' do
      advance(term, at: period_end + 1.day)

      described_class.call(term:, days: 5, now: period_end + 1.day)

      expect(term.reload.grace_ends_at).to eq(period_end + 7.days + 5.days)
      expect(advance(term, at: period_end + 9.days).status).to eq('past_due')
      expect(advance(term, at: period_end + 13.days).status).to eq('unpaid')
    end

    it 'brings a lapsed subscription back, past due, when the new date is still ahead' do
      advance(term, at: period_end + 8.days)
      expect(subscription.status).to eq('unpaid')

      described_class.call(term:, days: 10, now: period_end + 8.days)

      expect(subscription).to have_attributes(status: 'past_due', ends_at: nil)
    end

    it 'refuses a subscription that is not behind, and a number of days that makes no sense' do
      expect { described_class.call(term:, days: 5) }.to raise_error(described_class::Refused)
      advance(term, at: period_end + 1.day)
      [0, -1, 91, 'abc'].each { |days| expect { described_class.call(term:, days:) }.to raise_error(described_class::Refused) }
    end
  end

  describe BetterTogether::Billing::Subscriptions::MoveToCurrentPrice do
    it 'puts the subscriber on the plan\'s price today, for the next invoice' do
      sub_plan.update_columns(amount_cents: 5000) # rubocop:disable Rails/SkipsModelValidations

      described_class.call(term: term.reload)

      expect(term.reload.unit_amount_cents).to eq(5000)
      expect(generate_renewal(term, at: Time.utc(2027, 2, 20)).order.total_cents).to eq(5000)
    end
  end

  describe BetterTogether::Billing::Subscriptions::Adopt do
    let(:customer) { buyer.add_payment_processor(:local, platform: host_platform).api_record }
    let(:pay_subscription) do
      customer.subscribe(name: 'processor-sub', plan: sub_plan.identifier, current_period_start: start_time,
                         current_period_end: start_time + 30.days)
    end
    let(:order) do
      travel_to(start_time) do
        placed = place_order(purpose: 'subscription', payment_method: 'cash', line_items: [{ purchasable: sub_plan }])
        placed.tap { pay_manually(placed) }
      end
    end

    it 'links a subscription a processor renews to the order that bought it, without renewing it here' do
      adopted = described_class.call(pay_subscription:, order:)

      expect(adopted).to have_attributes(pay_subscription:, plan: sub_plan, unit_amount_cents: 3000, platform_id: host_platform.id)
      expect(order.reload).to have_attributes(pay_subscription:, subject: adopted)
      expect(adopted.periods).to be_empty
    end

    it 'is done once however often it runs' do
      first = described_class.call(pay_subscription:, order:)

      expect(described_class.call(pay_subscription:, order:)).to eq(first)
    end

    it 'refuses a subscription on another platform' do
      other = create(:better_together_platform)
      foreign_customer = buyer.add_payment_processor(:local, platform: other).api_record
      foreign = foreign_customer.subscribe(name: 'x', plan: 'x', current_period_start: start_time, current_period_end: start_time + 30.days)

      expect { described_class.call(pay_subscription: foreign, order:) }.to raise_error(described_class::Refused)
    end
  end
end
