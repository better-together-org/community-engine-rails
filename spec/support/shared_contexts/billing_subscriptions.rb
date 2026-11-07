# frozen_string_literal: true

# A monthly plan paid for with cash or store credit, both switched on for the host platform, and the helpers
# to start a subscription and to move time. Subscription orders are followed up by a job after they are paid,
# so the helpers run it.
RSpec.shared_context 'with subscription fixtures' do
  include_context 'with offline payment fixtures'

  let(:sub_plan) do
    create(:better_together_billing_plan, processor: nil, processor_price_id: nil, processor_product_id: nil, billing_interval: 'month',
                                          amount_cents: 3000, currency: 'USD', accepted_payment_methods: %w[cash store_credit],
                                          grace_days: 7, renewal_lead_days: 14)
  end
  let(:credit) { BetterTogether::Billing::Credit }
  let(:start_time) { Time.utc(2027, 1, 31, 15, 0, 0) }

  before do
    host_platform.update_columns(time_zone: 'UTC') # rubocop:disable Rails/SkipsModelValidations
    host_platform.billing_processor_settings.create!(processor: 'store_credit', enabled: true, acknowledge: true,
                                                     purposes: %w[subscription one_time ticket exchange])
    enable_offline('cash', purposes: %w[subscription one_time])
  end

  def give_credit(cents, holder: buyer)
    credit::Grant.call(platform: host_platform, holder:, amount_cents: cents, currency: 'USD', origin: 'steward_grant', actor: steward,
                       idempotency_key: SecureRandom.uuid)
  end

  # Starts a subscription to `sub_plan`, paid at `start_time` by `method`.
  def start_subscription(method: 'cash', at: start_time, plan: sub_plan, payer: buyer, **attrs)
    travel_to(at) do
      give_credit(plan.amount_cents, holder: payer) if method == 'store_credit'
      order = place_order(buyer: payer, purpose: 'subscription', payment_method: method, lines: [{ purchasable: plan }], **attrs)
      pay_manually(order) unless method == 'store_credit'
      follow_up
      order.reload.subject
    end
  end

  # The platform changes the subscription agreement, so everyone who accepted it must accept it again.
  def change_subscription_agreement
    BetterTogether::Agreement.find_by!(platform: host_platform, identifier: 'subscription_agreement').update!(title: 'Changed terms')
  end

  def pay_manually(order, received_on: nil)
    transition.receive(order.offline_payments.first, by: steward, received_on:)
    order.reload
  end

  # Runs the jobs that follow a payment (starting or renewing a subscription).
  def follow_up(&) = perform_enqueued_jobs(&)

  def generate_renewal(term, at:)
    travel_to(at) { BetterTogether::Billing::Subscriptions::GenerateRenewal.call(term: term.reload) }
  end

  def advance(term, at:)
    travel_to(at) { BetterTogether::Billing::Subscriptions::Advance.call(term: term.reload) }
    term.reload.pay_subscription
  end

  def pay_renewal(term, at:, received_on: nil)
    travel_to(at) do
      order = term.reload.periods.last.order
      pay_manually(order, received_on:)
      follow_up
    end
    term.reload
  end
end
