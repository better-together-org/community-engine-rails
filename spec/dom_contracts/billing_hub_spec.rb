# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the buyer's billing page: the stable identifiers that documentation screenshots and tooling target.
RSpec.describe 'Billing hub DOM contract', type: :request do # rubocop:disable RSpec/DescribeClass
  include_context 'with subscription fixtures'
  include_context 'with billing switched on'

  let(:locale) { I18n.default_locale }

  def expect_ids(*ids)
    ids.each { |id| expect(response.body).to include(%(id="#{id}")), "expected id=#{id.inspect} in the page" }
  end

  def dom_id(*) = ActionView::RecordIdentifier.dom_id(*)

  it 'exposes a section and a link per area, and an id per plan, order and credit account' do
    term = start_subscription
    order = term.reload.periods.first.order
    account = BetterTogether::Billing::Credit::Grant.call(platform: host_platform, holder: buyer, amount_cents: 2500, currency: 'USD',
                                                          origin: 'steward_grant', actor: steward, idempotency_key: 'hub').account
    sign_in buyer_user

    get "/#{locale}/billing"

    expect_ids('billing-hub-page', 'billing-hub-plans', 'billing-hub-orders', 'billing-hub-credit', 'billing-hub-access',
               'billing-hub-plans-link', 'billing-hub-orders-link', 'billing-hub-credit-link', 'billing-hub-access-link',
               'billing-hub-access-count', dom_id(term, :hub), dom_id(order, :hub), dom_id(account, :hub))
  end

  it 'exposes the empty notes' do
    sign_in buyer_user

    get "/#{locale}/billing"

    expect_ids('billing-hub-plans-empty', 'billing-hub-orders-empty', 'billing-hub-credit-empty')
  end
end
