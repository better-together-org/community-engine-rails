# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Subscription jobs' do # rubocop:disable RSpec/DescribeClass
  include_context 'with subscription fixtures'

  let(:term) { start_subscription }
  let(:period_end) { Time.utc(2027, 2, 28, 15) }

  describe BetterTogether::Billing::GenerateRenewalsJob do
    it 'runs on the billing queue' do
      expect(described_class.new.queue_name).to include('billing')
    end

    it 'makes the invoice for each subscription inside its lead time, and only those' do
      term
      late = start_subscription(at: Time.utc(2027, 2, 10), payer: create(:better_together_person))

      travel_to(Time.utc(2027, 2, 20)) { described_class.perform_now }

      expect(term.reload.periods.count).to eq(2)
      expect(late.reload.periods.count).to eq(1)
    end

    it 'goes on to the next subscription when one fails' do
      term
      other = start_subscription(payer: create(:better_together_person))
      allow(BetterTogether::Billing::Subscriptions::GenerateRenewal).to receive(:call).and_wrap_original do |original, **args|
        raise 'boom' if args[:term].id == term.id

        original.call(**args)
      end
      allow(BetterTogether).to receive(:report_error)

      travel_to(Time.utc(2027, 2, 20)) { described_class.perform_now }

      expect(other.reload.periods.count).to eq(2)
      expect(BetterTogether).to have_received(:report_error)
    end
  end

  describe BetterTogether::Billing::AdvanceSubscriptionsJob do
    it 'moves a subscription past due when its period ended unpaid' do
      term
      travel_to(period_end + 1.hour) { described_class.perform_now }

      expect(term.reload.pay_subscription.status).to eq('past_due')
    end

    it 'tries again to pay a renewal from credit that has since been topped up' do
      credit_term = start_subscription(method: 'store_credit', payer: create(:better_together_person))
      period = generate_renewal(credit_term, at: Time.utc(2027, 2, 20))
      expect(period.order).to be_open
      give_credit(3000, holder: credit_term.payer)

      travel_to(Time.utc(2027, 2, 21)) { follow_up { described_class.perform_now } }

      expect(period.reload.order).to be_paid
    end
  end

  describe BetterTogether::Billing::RemindRenewalsJob do
    before do
      term
      generate_renewal(term, at: Time.utc(2027, 2, 20))
      clear_notices
    end

    it 'reminds the payer of an unpaid invoice a week out, and again a day out, once each' do
      deliver_now do
        travel_to(period_end - 6.days) { 2.times { described_class.perform_now } }
        travel_to(period_end - 23.hours) { described_class.perform_now }
      end

      expect(kinds_for(buyer).count('renewal_reminder')).to eq(2)
    end

    it 'says nothing a month out' do
      deliver_now { travel_to(period_end - 30.days) { described_class.perform_now } }

      expect(kinds_for(buyer)).not_to include('renewal_reminder')
    end

    it 'says nothing about an invoice that is paid' do
      pay_renewal(term, at: Time.utc(2027, 2, 21))
      clear_notices
      deliver_now { travel_to(period_end - 23.hours) { described_class.perform_now } }

      expect(kinds_for(buyer)).not_to include('renewal_reminder')
    end

    it 'warns a day before the extra time runs out' do
      advance(term, at: period_end + 1.hour)
      clear_notices

      deliver_now { travel_to(period_end + 6.days + 2.hours) { described_class.perform_now } }

      expect(kinds_for(buyer)).to include('grace_ending')
    end
  end

  describe BetterTogether::Billing::SubscriptionOrderPaidJob do
    it 'starts the subscription for a paid first order' do
      term

      expect(term).to be_present
      expect(Pay::Subscription.count).to eq(1)
    end

    it 'runs after the payment, from the order being settled' do
      order = travel_to(start_time) do
        pay_manually(place_order(purpose: 'subscription', payment_method: 'cash', lines: [{ purchasable: sub_plan }]))
      end

      expect(enqueued_jobs.map { |job| job['job_class'] }).to include(described_class.name)
      expect(order).to be_paid
    end
  end
end
