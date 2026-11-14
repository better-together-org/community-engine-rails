# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the subscription screens: the stable identifiers that documentation screenshots and
# downstream tooling target. Runs in normal CI (no RUN_DOCS_SCREENSHOTS gate).
RSpec.describe 'Billing subscriptions DOM contract', type: :request do # rubocop:disable RSpec/DescribeClass
  include_context 'with subscription fixtures'
  include_context 'with billing switched on'

  let(:locale) { I18n.default_locale }
  let!(:term) { start_subscription }

  def expect_ids(*ids)
    ids.each { |id| expect(response.body).to include(%(id="#{id}")), "expected id=#{id.inspect} in the page" }
  end

  def dom_id(*) = ActionView::RecordIdentifier.dom_id(*)

  it 'exposes the payer\'s list and one subscription' do
    sign_in buyer_user

    get "/#{locale}/billing/subscriptions"
    expect_ids('billing-subscriptions-page', 'billing-subscriptions-table', dom_id(term))
    expect(response.body).to include('subscription-status-badge')

    get "/#{locale}/billing/subscriptions/#{term.id}"
    expect_ids(dom_id(term, :show_page), dom_id(term, :details), 'subscription-through', 'subscription-price', 'subscription-method',
               'subscription-actions', 'subscription-cancel-btn', 'subscription-method-change', 'subscription-method-change-form',
               'subscription-method-change-select', 'subscription-method-change-btn', dom_id(term, :periods), dom_id(term.periods.first))
    expect(response.body).to include('period-status-badge')
  end

  it 'exposes the steward\'s list and one subscriber' do
    sign_in steward_user

    get "/#{locale}/billing/subscribers"
    expect_ids('billing-subscribers-page', 'billing-subscribers-table', dom_id(term))

    get "/#{locale}/billing/subscribers/#{term.id}"
    expect_ids(dom_id(term, :subscriber_page), 'subscriber-through', 'subscriber-method', 'subscriber-actions', 'subscriber-waive-btn',
               'subscriber-price-btn', 'subscriber-cancel-btn', 'subscriber-cancel-now-btn', 'subscriber-extend-form', 'subscriber-extend-days',
               'subscriber-extend-btn', dom_id(term, :periods))
  end

  it 'links to them from the orders list and the payment methods list' do
    sign_in buyer_user
    get "/#{locale}/billing/orders"
    expect_ids('billing-subscriptions-link')

    sign_in steward_user
    get "/#{locale}/billing/processor_settings"
    expect_ids('billing-subscribers-link')
  end

  it 'exposes the renewal fields on a recurring plan\'s form' do
    sign_in steward_user

    get "/#{locale}/billing/plans/#{sub_plan.id}/edit"

    expect_ids('billing-plan-renewal-fields', 'billing-plan-renewal-lead-days', 'billing-plan-grace-days')
  end
end
