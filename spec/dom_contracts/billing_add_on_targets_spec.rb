# frozen_string_literal: true

require 'rails_helper'

# DOM contract for extras: the hub section for extras a holder may buy later, and the product form's needed plans.
RSpec.describe 'Billing add-on targets DOM contract', type: :request do # rubocop:disable RSpec/DescribeClass
  include_context 'with subscription fixtures'
  include_context 'with billing switched on'
  include_context 'with billing extras'

  let(:locale) { I18n.default_locale }
  let(:attrs) { { platform: host_platform, processor: nil, accepted_payment_methods: %w[cash], currency: 'USD' } }
  let(:add_on) { create_extra(amount_cents: 700, needs: :any_plan) }

  def dom_id(*) = ActionView::RecordIdentifier.dom_id(*)

  def expect_ids(*ids)
    ids.each { |id| expect(response.body).to include(%(id="#{id}")), "expected id=#{id.inspect} in the page" }
  end

  it 'exposes the hub add-ons section, hint, and a row and buy link per add-on' do
    start_subscription
    add_on
    sign_in buyer_user

    get "/#{locale}/billing"

    expect_ids('billing-hub-add-ons', 'billing-hub-add-ons-hint', dom_id(add_on, :hub_add_on), dom_id(add_on, :hub_add_on_buy))
  end

  it 'exposes a locked add-on with its reason to a buyer who holds no plan yet' do
    add_on
    sign_in buyer_user

    get "/#{locale}/billing"

    expect_ids('billing-hub-locked-add-ons', 'billing-hub-locked-add-ons-hint', dom_id(add_on, :hub_locked_add_on),
               dom_id(add_on, :hub_locked_reason))
    expect(response.body).not_to include(%(id="#{dom_id(add_on, :hub_add_on_buy)}"))
  end

  it 'exposes the product form requirements and a checkbox per plan' do
    sub_plan
    sign_in steward_user
    get "/#{locale}/billing/products/#{add_on.product_id}/edit"

    expect_ids('billing-product-requirements', dom_id(sub_plan, :needed_by_product))
  end
end
