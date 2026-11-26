# frozen_string_literal: true

# @hermetic
require 'rails_helper'

# Real multi-threaded, multi-connection examples for the money paths: paying an order, refunding a
# payment, spending credit and redeeming a promotion. Each race must end with exactly one winner.
#
# The `:js` tag is what makes commits from worker threads visible to each other and to the main thread:
# it switches the global DatabaseCleaner hook to the `:deletion` strategy (see
# spec/lib/better_together/quotas_concurrency_spec.rb). Do not set a strategy by hand here.
RSpec.describe 'Billing money paths under concurrency', :js do # rubocop:disable RSpec/DescribeClass
  include_context 'with store credit fixtures'

  let(:refused) { BetterTogether::Billing::Orders::AddPayment::Refused }
  let(:order) { place_order }

  # Runs the blocks at the same moment, each on its own connection, and returns each outcome
  # (the value, or the exception it raised) in order. A latch releases them together; Thread#value
  # means a crash is never swallowed, and the pool is large enough for one connection per thread.
  def race(*actions)
    latch = Concurrent::CountDownLatch.new(1)
    threads = actions.map do |action|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          latch.wait(10)
          action.call
        rescue StandardError => e
          e
        end
      end
    end
    latch.count_down
    threads.map(&:value)
  end

  def paying(key, amount = nil)
    -> { BetterTogether::Billing::Orders::AddPayment.call(order:, payment_method: 'store_credit', amount_cents: amount, idempotency_key: key) }
  end

  def refunding(key, amount = 4500)
    -> { BetterTogether::Billing::Refunds::Record.call(payment:, amount_cents: amount, idempotency_key: key, notify: false) }
  end

  def spending(key)
    lambda do
      BetterTogether::Billing::Credit::Spend.call(account: account_of, amount_cents: 1000, purpose: 'one_time', source: payment,
                                                  idempotency_key: key)
    end
  end

  def promotion_code(**attrs)
    BetterTogether::Billing::Promotions::Create.call(platform: host_platform, actor: steward, name: 'Race', amount_cents: 1500,
                                                     currency: 'USD', **attrs)
  end

  def redeeming(code, person) = -> { BetterTogether::Billing::Promotions::Redeem.call(platform: host_platform, person:, code:) }

  def failures(outcomes) = outcomes.grep(StandardError)
  def successes(outcomes) = outcomes.grep_v(StandardError)

  describe 'paying the same order' do
    it 'lets only one of two different full payments through, and spends the credit once' do
      grant_credit(9000)
      order

      outcomes = race(paying('first', 4500), paying('second', 4500))

      expect(successes(outcomes).size).to eq(1)
      expect(failures(outcomes).map(&:class)).to eq([refused])
      expect(order.reload).to be_paid
      expect(order.payments.where(status: 'succeeded').count).to eq(1)
      expect(account_of.reload.balance_cents).to eq(4500)
    end

    it 'makes one payment when the same request arrives twice' do
      grant_credit(9000)
      order

      outcomes = race(paying('same', 4500), paying('same', 4500))

      expect(failures(outcomes)).to be_empty
      expect(outcomes.map(&:id).uniq.size).to eq(1)
      expect(order.payments.count).to eq(1)
      expect(account_of.reload.balance_cents).to eq(4500)
    end
  end

  describe 'refunding the same payment' do
    let(:payment) do
      BetterTogether::Billing::Payments::Succeed.call(
        BetterTogether::Billing::Payments::Create.call(order:, processor: 'fake', amount_cents: 4500, idempotency_key: 'req')
      )
    end

    it 'refunds a payment in full only once, however many refunds ask for all of it' do
      payment

      outcomes = race(refunding('one'), refunding('two'), refunding('three'))

      expect(successes(outcomes).size).to eq(1)
      expect(failures(outcomes).map(&:class).uniq).to eq([BetterTogether::Billing::Refunds::Record::Refused])
      expect(payment.refunds.sum(:amount_cents)).to eq(4500)
      expect(payment.reload).to be_refunded
    end

    it 'never refunds more in total than was paid when parts race' do
      payment

      race(refunding('a', 3000), refunding('b', 3000), refunding('c', 3000))

      expect(payment.refunds.sum(:amount_cents)).to be <= 4500
      expect(payment.refunds.count).to eq(1)
    end

    it 'records one refund when the same request is repeated at the same moment' do
      payment

      outcomes = race(refunding('same'), refunding('same'))

      expect(failures(outcomes)).to be_empty
      expect(outcomes.map(&:id).uniq.size).to eq(1)
      expect(payment.refunds.count).to eq(1)
    end
  end

  describe 'spending the same credit' do
    let(:payment) { create(:better_together_billing_payment, order:, amount_cents: 1000, processor: 'store_credit') }

    it 'spends a balance that covers one spend only once' do
      grant_credit(1500)
      payment

      outcomes = race(spending('one'), spending('two'))

      expect(successes(outcomes).size).to eq(1)
      expect(failures(outcomes).map(&:class)).to eq([BetterTogether::Billing::Credit::Refused])
      expect(account_of.reload.balance_cents).to eq(500)
      expect(account_of).to be_consistent
    end
  end

  describe 'redeeming a promotion' do
    let(:redeem) { BetterTogether::Billing::Promotions::Redeem }
    let(:invalid) { redeem::Invalid }

    it 'gives one person the credit once when they redeem the same code twice at the same moment' do
      made = promotion_code
      person = create(:better_together_person)

      outcomes = race(redeeming(made.code, person), redeeming(made.code, person))

      expect(successes(outcomes).size).to eq(1)
      expect(failures(outcomes).map(&:class)).to eq([invalid])
      expect(made.promotion.reload.redemptions_count).to eq(1)
      expect(made.promotion.redemptions.count).to eq(1)
      expect(account_of(person).balance_cents).to eq(1500)
    end

    it 'never goes past the cap when several people redeem the last use at the same moment' do
      made = promotion_code(max_redemptions: 1)
      people = create_list(:better_together_person, 3)

      outcomes = race(*people.map { |person| redeeming(made.code, person) })

      expect(successes(outcomes).size).to eq(1)
      expect(failures(outcomes).map(&:class).uniq).to eq([invalid])
      expect(made.promotion.reload.redemptions_count).to eq(1)
      expect(made.promotion.redemptions.count).to eq(1)
      expect(BetterTogether::Billing::CreditLot.where(origin: 'promotion').count).to eq(1)
    end
  end
end
