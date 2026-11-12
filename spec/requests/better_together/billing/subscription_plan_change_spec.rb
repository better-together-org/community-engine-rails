# frozen_string_literal: true

require 'rails_helper'

# A payer moves a subscription to another plan from the next period.
RSpec.describe 'Billing subscription plan change', type: :request do # rubocop:disable RSpec/DescribeClass, RSpecRails/InferredSpecType
  include_context 'with subscription fixtures'
  include_context 'with billing switched on'

  let(:locale) { :en }
  let(:term) { start_subscription }
  let!(:bigger) do
    create(:better_together_billing_plan, processor: nil, processor_price_id: nil, processor_product_id: nil, billing_interval: 'month',
                                          amount_cents: 5000, currency: 'USD', accepted_payment_methods: %w[cash store_credit], listed: true)
  end
  let(:service) { BetterTogether::Billing::Subscriptions::ChangePlan }

  def change_path = better_together.change_plan_billing_subscription_path(term, locale:)

  before do
    term
    sign_in buyer_user
  end

  it 'offers the other plans on the same schedule' do
    get better_together.billing_subscription_path(term, locale:)

    expect(response.body).to include('subscription-plan-change-select', bigger.id)
  end

  it 'saves the choice and changes nothing until the next period' do
    post change_path, params: { plan_id: bigger.id }

    expect(term.reload).to have_attributes(pending_plan: bigger, plan: sub_plan, unit_amount_cents: 3000)
  end

  it 'withdraws the choice' do
    post change_path, params: { plan_id: bigger.id }

    delete change_path

    expect(term.reload.pending_plan).to be_nil
  end

  it 'moves to the new plan and price when the next period is made' do
    service.request(term:, plan: bigger)

    generate_renewal(term, at: start_time + 20.days)

    expect(term.reload).to have_attributes(plan: bigger, unit_amount_cents: 5000, pending_plan: nil)
    expect(term.periods.last.order.total_cents).to be >= 5000
  end

  it 'refuses a plan on another schedule' do
    yearly = create(:better_together_billing_plan, processor: nil, processor_price_id: nil, processor_product_id: nil, billing_interval: 'year',
                                                   amount_cents: 30_000, currency: 'USD', accepted_payment_methods: %w[cash])

    expect { service.request(term:, plan: yearly) }.to raise_error(service::Refused) { |e| expect(e.code).to eq(:different_schedule) }
  end

  it 'refuses the plan it is already on' do
    expect { service.request(term:, plan: sub_plan) }.to raise_error(service::Refused) { |e| expect(e.code).to eq(:same_plan) }
  end

  it 'turns another person away' do
    sign_in other_buyer_user

    post change_path, params: { plan_id: bigger.id }

    expect(term.reload.pending_plan).to be_nil
  end

  it 'does not let a stray update change the plan' do
    expect(term.update(plan: bigger)).to be(false)
  end
end
