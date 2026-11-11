# frozen_string_literal: true

require 'rails_helper'

# A plan that costs nothing is taken without choosing a way to pay: the agreements still come first.
# It has no tax to work out, so it asks for no billing address either.
RSpec.describe 'Checkout for a free plan', :request do # rubocop:disable RSpec/DescribeClass
  include_context 'with orders fixtures'
  include_context 'with builtin billing processors'
  include_context 'with billing switched on'

  let(:locale) { :en }
  let(:password) { 'SecureTest123!@#' }
  let(:member) { find_or_create_test_user("free-member-#{SecureRandom.hex(4)}@example.test", password) }
  let(:buyer) { member.person }
  let(:free_plan) do
    create(:better_together_billing_plan, :one_time, processor: nil, processor_price_id: nil, processor_product_id: nil,
                                                     accepted_payment_methods: [], amount_cents: 0, currency: 'USD')
  end

  before do
    BetterTogether::Billing::PurchaseAgreementSeeds.call(host_platform).each_value { |agreement| agreement.update!(lifecycle_state: 'active') }
    sign_in member
  end

  def ticks
    BetterTogether::Agreement.all.to_h { |a| [BetterTogether::ApplicationController.helpers.agreement_acceptance_param_name(a), '1'] }
  end

  it 'shows the agreements and the place-order button straight away, with no ways of paying to choose' do
    get better_together.new_billing_checkout_path(locale:, plan_id: free_plan.id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('billing-checkout-place-btn')
    expect(response.body).not_to include('billing-checkout-methods', 'billing-checkout-no-methods')
  end

  it 'says Free, offers Get it free, and leaves out the tax note and the billing address' do
    get better_together.new_billing_checkout_path(locale:, plan_id: free_plan.id)

    expect_html_content('Free')
    expect(response.body).to include('value="Get it free"')
    expect_no_html_content('US$0.00')
    expect(response.body).not_to include('billing-checkout-tax-note', 'billing_address', 'Place order')
  end

  it 'keeps no billing address on the order' do
    post better_together.billing_checkout_path(locale:), params: { plan_id: free_plan.id }.merge(ticks)

    expect(host_platform.billing_orders.last.billing_address).to be_blank
  end

  it 'places the order with no payment method, paid at once' do
    post better_together.billing_checkout_path(locale:),
         params: { plan_id: free_plan.id }.merge(ticks)

    order = host_platform.billing_orders.order(:created_at).last
    expect(response).to redirect_to(better_together.billing_order_path(order, locale:))
    expect(order).to be_paid
    expect(order.payments).to be_empty
  end

  it 'ignores a payment method sent for it' do
    post better_together.billing_checkout_path(locale:),
         params: { plan_id: free_plan.id, payment_method: 'cash' }.merge(ticks)

    expect(host_platform.billing_orders.last).to be_paid
  end

  it 'still needs the agreements accepted' do
    post better_together.billing_checkout_path(locale:), params: { plan_id: free_plan.id }

    expect(response).to have_http_status(:unprocessable_content)
    expect(host_platform.billing_orders).to be_empty
  end
end
