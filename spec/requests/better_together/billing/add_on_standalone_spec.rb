# frozen_string_literal: true

require 'rails_helper'

# An add-on bought on its own, later, by someone who already holds a plan it extends.
RSpec.describe 'Add-ons bought on their own' do # rubocop:disable RSpec/DescribeClass
  include BetterTogether::BillingAddressHelpers

  include_context 'with orders fixtures'
  include_context 'with builtin billing processors'
  include_context 'with billing switched on'

  let(:locale) { :en }
  let(:member) { find_or_create_test_user("standalone-#{SecureRandom.hex(4)}@example.test", 'SecureTest123!@#') }
  let(:buyer) { member.person }
  let(:attrs) { { processor: nil, accepted_payment_methods: %w[cash], currency: 'USD' } }
  let(:plan) { create(:better_together_billing_plan, :unlinked, :one_time, **attrs, amount_cents: 2500) }
  let(:other_plan) { create(:better_together_billing_plan, :unlinked, :one_time, **attrs, amount_cents: 1500) }
  let(:add_on) { create(:better_together_billing_plan, :unlinked, :one_time, **attrs, amount_cents: 700, add_on: true) }

  def hold(held_plan)
    order = place_order(buyer:, purpose: 'one_time', line_items: [{ purchasable: held_plan }], payment_method: 'cash')
    order.update!(status: 'paid', paid_at: Time.current)
  end

  def target!(add_on_plan, *plans) = plans.each { |p| BetterTogether::Billing::PlanAddOn.create!(plan: p, add_on: add_on_plan) }
  def new_path(id) = better_together.new_billing_checkout_path(locale:, plan_id: id)

  before do
    host_platform.billing_processor_settings.create!(processor: 'cash', enabled: true, acknowledge: true, settings: { 'instructions' => 'x' })
    sign_in member
  end

  it 'is refused to a buyer who holds no plan' do
    get new_path(add_on.id)

    expect(response).to have_http_status(:not_found)
  end

  it 'is open to a holder of any plan when the add-on names none' do
    hold(plan)
    get new_path(add_on.id)

    expect(response).to have_http_status(:ok)
  end

  it 'is open to a holder of a plan it extends and refused to a holder of another' do
    target!(add_on, plan)
    hold(other_plan)
    get new_path(add_on.id)
    expect(response).to have_http_status(:not_found)

    hold(plan)
    get new_path(add_on.id)
    expect(response).to have_http_status(:ok)
  end

  it 'does not count a refunded purchase as holding the plan' do
    hold(plan)
    BetterTogether::Billing::Order.where(buyer_id: buyer.id).update_all(status: 'refunded') # rubocop:disable Rails/SkipsModelValidations
    get new_path(add_on.id)

    expect(response).to have_http_status(:not_found)
  end

  it 'offers the add-on with a plan it extends and not with another' do
    target!(add_on, plan)
    get new_path(plan.id)
    expect(response.body).to include(ActionView::RecordIdentifier.dom_id(add_on, :add_on))

    get new_path(other_plan.id)
    expect(response.body).not_to include(ActionView::RecordIdentifier.dom_id(add_on, :add_on))
  end

  it 'places an add-on only order that gives no entitlement and starts no subscription' do
    hold(plan)
    BetterTogether::Billing::PurchaseAgreementSeeds.call(host_platform).each_value { |a| a.update!(lifecycle_state: 'active') }
    address = create_billing_address_for(buyer)
    ticks = BetterTogether::Agreement.all.to_h { |a| [BetterTogether::ApplicationController.helpers.agreement_acceptance_param_name(a), '1'] }

    post better_together.billing_checkout_path(locale:),
         params: { plan_id: add_on.id, payment_method: 'cash', **billing_address_params(address) }.merge(ticks)

    order = BetterTogether::Billing::Order.order(:created_at).last
    expect(order.line_items.map(&:purchasable)).to eq([add_on])
    expect(host_platform.billing_entitlements.where(order_id: order.id)).to be_empty
  end

  it 'lists the add-on on the billing hub for a holder' do
    hold(plan)
    add_on
    get better_together.billing_hub_path(locale:)

    expect(response.body).to include('billing-hub-add-ons', ActionView::RecordIdentifier.dom_id(add_on, :hub_add_on_buy))
  end

  it 'leaves the hub section out for someone who holds nothing' do
    add_on
    get better_together.billing_hub_path(locale:)

    expect(response.body).not_to include('billing-hub-add-ons')
  end
end
