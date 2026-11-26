# frozen_string_literal: true

require 'rails_helper'

# Extras on a plan's order: a product's price that needs a plan, paid by local methods.
RSpec.describe 'Checkout add-ons' do # rubocop:disable RSpec/DescribeClass
  include BetterTogether::BillingAddressHelpers

  include_context 'with orders fixtures'
  include_context 'with builtin billing processors'
  include_context 'with billing switched on'
  include_context 'with billing extras'

  let(:locale) { :en }
  let(:member) { find_or_create_test_user("addon-member-#{SecureRandom.hex(4)}@example.test", 'SecureTest123!@#') }
  let(:plan_attrs) { { processor: nil, accepted_payment_methods: %w[cash], billing_interval: 'month', currency: 'USD' } }
  let(:plan) { create(:better_together_billing_plan, :unlinked, **plan_attrs, amount_cents: 2500) }
  let(:add_on) { create_extra(amount_cents: 700, needs: :any_plan) }

  before do
    host_platform.billing_processor_settings.create!(processor: 'cash', enabled: true, acknowledge: true,
                                                     settings: { 'instructions' => 'At the hall' })
    sign_in member
  end

  def new_path(plan_id: plan.id, **params) = better_together.new_billing_checkout_path(locale:, plan_id:, **params)

  it 'lists the add-ons beside the plan' do
    add_on
    get new_path

    expect(response.body).to include('billing-checkout-add-ons', "id=\"#{ActionView::RecordIdentifier.dom_id(add_on, :add_on)}\"")
  end

  it 'adds a ticked add-on to the order summary' do
    get new_path(add_on_ids: [add_on.id])

    expect(response.body).to include('billing-checkout-subtotal')
    expect(response.body).to include('$32.00')
  end

  it 'tells the buyer when a ticked add-on is no longer offered' do
    gone = add_on
    gone.archive!

    get new_path(add_on_ids: [gone.id])

    expect(response.body).to include('billing-checkout-add-ons-dropped')
  end

  it 'announces the updated total in a polite status region' do
    add_on
    get new_path(add_on_ids: [add_on.id])

    expect(response.body).to match(/id="billing-checkout-add-ons-status"[^>]*aria-live="polite"/)
    expect(response.body).to include('aria-describedby="billing-checkout-add-ons-status"')
  end

  describe 'placing the order' do
    let(:ticks) do
      BetterTogether::Billing::PurchaseAgreementSeeds.call(host_platform).each_value { |a| a.update!(lifecycle_state: 'active') }
      BetterTogether::Agreement.all.to_h { |a| [BetterTogether::ApplicationController.helpers.agreement_acceptance_param_name(a), '1'] }
    end
    let(:params) do
      address = create_billing_address_for(member.person)
      { plan_id: plan.id, payment_method: 'cash', add_on_ids: [add_on.id], **billing_address_params(address) }.merge(ticks)
    end

    it 'refuses when the total changed since the buyer reviewed it' do
      post better_together.billing_checkout_path(locale:), params: params.merge(expected_total_cents: 1)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('billing-checkout-error')
      expect(BetterTogether::Billing::Order.count).to eq(0)
    end

    it 'places the order once when the same form token is submitted twice' do
      with_token = params.merge(checkout_token: 'abc123', expected_total_cents: 3200)

      post better_together.billing_checkout_path(locale:), params: with_token
      post better_together.billing_checkout_path(locale:), params: with_token

      expect(BetterTogether::Billing::Order.count).to eq(1)
      expect(response).to redirect_to_billing_screen(better_together.billing_order_path(BetterTogether::Billing::Order.last, locale:))
    end
  end

  it 'does not let an extra be bought on its own by someone who holds no plan' do
    get better_together.new_billing_checkout_path(locale:, price_id: add_on.id)

    expect(response).to have_http_status(:not_found)
  end

  it 'places one order with a line for the plan and one for the add-on' do
    agreements = BetterTogether::Billing::PurchaseAgreementSeeds.call(host_platform)
    agreements.each_value { |agreement| agreement.update!(lifecycle_state: 'active') }
    address = create_billing_address_for(member.person)
    ticks = BetterTogether::Agreement.all.to_h do |a|
      [BetterTogether::ApplicationController.helpers.agreement_acceptance_param_name(a), '1']
    end

    post better_together.billing_checkout_path(locale:),
         params: { plan_id: plan.id, payment_method: 'cash', add_on_ids: [add_on.id], **billing_address_params(address) }.merge(ticks)

    order = BetterTogether::Billing::Order.order(:created_at).last
    expect(order.line_items.map(&:purchasable)).to contain_exactly(plan.current_price, add_on)
  end

  it 'hides an extra the buyer is not in the audience for' do
    add_on.product.update!(restricted_to_members: true)
    get new_path

    expect(response.body).not_to include(ActionView::RecordIdentifier.dom_id(add_on, :add_on))
  end
end
