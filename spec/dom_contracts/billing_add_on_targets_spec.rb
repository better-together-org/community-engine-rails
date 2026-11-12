# frozen_string_literal: true

require 'rails_helper'

# DOM contract for add-on targets: the hub section for add-ons a holder may buy later, and the steward form's target plans.
RSpec.describe 'Billing add-on targets DOM contract', type: :request do # rubocop:disable RSpec/DescribeClass
  include_context 'with subscription fixtures'
  include_context 'with billing switched on'

  let(:locale) { I18n.default_locale }
  let(:attrs) { { platform: host_platform, processor: nil, accepted_payment_methods: %w[cash], currency: 'USD' } }
  let(:add_on) { create(:better_together_billing_plan, :unlinked, :one_time, **attrs, add_on: true, amount_cents: 700) }

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

  it 'exposes the steward form target plans and a checkbox per plan' do
    sub_plan
    sign_in steward_user
    get "/#{locale}/billing/plans/#{add_on.id}/edit"

    expect_ids('billing-plan-add-on-targets', 'billing-plan-add-on-targets-hint', dom_id(sub_plan, :add_on_target))
  end
end
