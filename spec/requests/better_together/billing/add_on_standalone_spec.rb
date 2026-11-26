# frozen_string_literal: true

require 'rails_helper'

# An extra bought on its own, later, by someone who already holds a plan it needs.
RSpec.describe 'Extras bought on their own' do # rubocop:disable RSpec/DescribeClass
  include BetterTogether::BillingAddressHelpers

  include_context 'with orders fixtures'
  include_context 'with builtin billing processors'
  include_context 'with billing switched on'
  include_context 'with billing extras'

  let(:locale) { :en }
  let(:member) { find_or_create_test_user("standalone-#{SecureRandom.hex(4)}@example.test", 'SecureTest123!@#') }
  let(:buyer) { member.person }
  let(:attrs) { { processor: nil, accepted_payment_methods: %w[cash], currency: 'USD' } }
  let(:plan) { create(:better_together_billing_plan, :unlinked, **attrs, amount_cents: 2500) }
  let(:other_plan) { create(:better_together_billing_plan, :unlinked, **attrs, amount_cents: 1500) }
  let(:extra) { create_extra(amount_cents: 700, needs: :any_plan) }

  def hold(held_plan) = hold_plan!(held_plan, buyer)
  def new_path(id) = better_together.new_billing_checkout_path(locale:, price_id: id)
  def plan_path(id) = better_together.new_billing_checkout_path(locale:, plan_id: id)

  before do
    host_platform.billing_processor_settings.create!(processor: 'cash', enabled: true, acknowledge: true, settings: { 'instructions' => 'x' })
    sign_in member
  end

  it 'is refused to a buyer who holds no plan' do
    get new_path(extra.id)

    expect(response).to have_http_status(:not_found)
  end

  it 'is open to a holder of any plan when it needs any plan' do
    hold(plan)
    get new_path(extra.id)

    expect(response).to have_http_status(:ok)
  end

  it 'is open to a holder of a plan it needs and refused to a holder of another' do
    needy = create_extra(needs: plan)
    hold(other_plan)
    get new_path(needy.id)
    expect(response).to have_http_status(:not_found)

    hold(plan)
    get new_path(needy.id)
    expect(response).to have_http_status(:ok)
  end

  it 'does not count a revoked entitlement as holding the plan' do
    hold(plan).update!(status: 'revoked')
    get new_path(extra.id)

    expect(response).to have_http_status(:not_found)
  end

  it 'offers the extra with a plan it needs and not with another' do
    needy = create_extra(needs: plan)
    get plan_path(plan.id)
    expect(response.body).to include(ActionView::RecordIdentifier.dom_id(needy, :add_on))

    get plan_path(other_plan.id)
    expect(response.body).not_to include(ActionView::RecordIdentifier.dom_id(needy, :add_on))
  end

  it 'places an extra only order that gives no plan entitlement and starts no subscription' do
    hold(plan)
    BetterTogether::Billing::PurchaseAgreementSeeds.call(host_platform).each_value { |a| a.update!(lifecycle_state: 'active') }
    address = create_billing_address_for(buyer)
    ticks = BetterTogether::Agreement.all.to_h { |a| [BetterTogether::ApplicationController.helpers.agreement_acceptance_param_name(a), '1'] }

    post better_together.billing_checkout_path(locale:),
         params: { price_id: extra.id, payment_method: 'cash', **billing_address_params(address) }.merge(ticks)

    order = BetterTogether::Billing::Order.order(:created_at).last
    expect(order.line_items.map(&:purchasable)).to eq([extra])
    expect(host_platform.billing_entitlements.where(order_id: order.id, product_id: plan.id)).to be_empty
  end

  it 'lists the extra on the billing hub for a holder' do
    hold(plan)
    extra
    get better_together.billing_hub_path(locale:)

    expect(response.body).to include('billing-hub-add-ons', ActionView::RecordIdentifier.dom_id(extra, :hub_add_on_buy))
  end

  it 'leaves the hub section out for someone who holds nothing' do
    extra
    get better_together.billing_hub_path(locale:)

    expect(response.body).not_to include('billing-hub-add-ons')
  end
end
