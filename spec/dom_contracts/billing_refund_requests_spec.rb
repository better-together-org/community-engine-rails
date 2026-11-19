# frozen_string_literal: true

require 'rails_helper'

# DOM contract for refund requests: the stable identifiers a buyer and a steward use.
RSpec.describe 'Billing refund requests DOM contract', type: :request do # rubocop:disable RSpec/DescribeClass
  include_context 'with offline payment fixtures'
  include_context 'with billing switched on'

  let(:locale) { I18n.default_locale }
  let(:order) { place_offline('cash') }
  let(:offline) { offline_for(order) }

  before do
    transition.receive(offline, by: steward)
    order.reload
  end

  def expect_ids(*ids)
    ids.each { |id| expect(response.body).to include(%(id="#{id}")), "expected id=#{id.inspect} in the page" }
  end

  def request_for(buyer_person)
    BetterTogether::Billing::RefundRequest.create!(order:, platform_id: order.platform_id, requester: buyer_person, currency: order.currency,
                                                   reason: 'other', amount_cents: 1000, details: 'Because')
  end

  it 'offers the buyer the way to ask, on their order' do
    sign_in buyer_user

    get "/#{locale}/billing/orders/#{order.id}"

    expect_ids('billing-order-refund-requests', 'billing-order-ask-refund-link')
  end

  it 'gives the buyer the form' do
    sign_in buyer_user

    get "/#{locale}/billing/orders/#{order.id}/refund_requests/new"

    expect_ids('billing-refund-request-page', 'billing-refund-request-form', 'billing-refund-request-refundable',
               'billing-refund-request-reason', 'billing-refund-request-amount', 'billing-refund-request-details',
               'billing-refund-request-submit')
  end

  it 'shows the buyer a waiting request with a way to withdraw it' do
    request = request_for(buyer)
    sign_in buyer_user

    get "/#{locale}/billing/orders/#{order.id}"

    expect_ids(ActionView::RecordIdentifier.dom_id(request), ActionView::RecordIdentifier.dom_id(request, :status),
               ActionView::RecordIdentifier.dom_id(request, :withdraw))
  end

  it 'lists the queue for a steward' do
    request = request_for(buyer)
    sign_in steward_user

    get "/#{locale}/billing/refund_requests"

    expect_ids('billing-refund-requests-page', 'billing-refund-requests-filter', 'billing-refund-requests-table',
               ActionView::RecordIdentifier.dom_id(request))
  end

  it 'gives the steward the decision form' do
    request = request_for(buyer)
    sign_in steward_user

    get "/#{locale}/billing/refund_requests/#{request.id}"

    expect_ids(ActionView::RecordIdentifier.dom_id(request, :show_page), ActionView::RecordIdentifier.dom_id(request, :details),
               'billing-refund-decision-form', 'billing-refund-decision-refundable', 'billing-refund-decision-amount',
               'billing-refund-decision-note', 'billing-refund-approve-btn', 'billing-refund-decline-btn')
  end

  it 'links the sales page to the queue' do
    sign_in steward_user

    get "/#{locale}/billing/sales"

    expect_ids('billing-sales-refund-requests-link')
  end

  it 'shows the refund policy and its box when the platform has one in force' do
    purchase_agreements_for(host_platform)
    policy = BetterTogether::Agreement.find_by!(platform: host_platform, identifier: 'refund_policy')
    policy.update!(lifecycle_state: 'active')
    sign_in buyer_user

    get "/#{locale}/billing/orders/#{order.id}/refund_requests/new"

    expect_ids('billing-refund-policy', 'billing-refund-policy-view', 'billing-refund-policy-accept')
    policy.update!(lifecycle_state: 'draft')
  end
end
