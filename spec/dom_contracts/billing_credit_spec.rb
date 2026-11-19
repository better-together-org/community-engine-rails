# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the store credit screens: the stable identifiers that documentation screenshots and
# downstream tooling target. Runs in normal CI (no RUN_DOCS_SCREENSHOTS gate).
RSpec.describe 'Billing store credit DOM contract', type: :request do # rubocop:disable RSpec/DescribeClass
  include_context 'with offline payment fixtures'
  include_context 'with billing switched on'

  let(:locale) { I18n.default_locale }
  let(:credit) { BetterTogether::Billing::Credit }
  let!(:lot) do
    credit::Grant.call(platform: host_platform, holder: buyer, amount_cents: 2500, currency: 'USD', origin: 'steward_grant', actor: steward,
                       idempotency_key: 'seed', expires_at: 5.days.from_now)
  end
  let(:account) { lot.account }

  def expect_ids(*ids)
    ids.each { |id| expect(response.body).to include(%(id="#{id}")), "expected id=#{id.inspect} in the page" }
  end

  def dom_id(*) = ActionView::RecordIdentifier.dom_id(*)

  it 'exposes the holder\'s credit: an id per account, lot and history entry' do
    sign_in buyer_user

    get "/#{locale}/billing/credit"

    expect_ids('billing-credit-page', dom_id(account), dom_id(account, :usable), dom_id(account, :lots), dom_id(account, :history),
               dom_id(lot), dom_id(account.entries.sole))
  end

  it 'exposes the steward\'s lookup, grant form and account list' do
    sign_in steward_user
    create(:better_together_person_platform_membership, joinable: host_platform, member: buyer)

    get "/#{locale}/billing/credit_accounts?person_id=#{buyer.id}"

    expect_ids('billing-credit-accounts-page', 'billing-credit-lookup-form', 'billing-credit-lookup-person', 'billing-credit-lookup-btn',
               'billing-credit-holder', 'billing-credit-grant-form', 'billing-credit-grant-amount', 'billing-credit-grant-currency',
               'billing-credit-grant-expires', 'billing-credit-grant-note', 'billing-credit-grant-btn', 'billing-credit-accounts-table',
               dom_id(account))
  end

  it 'exposes the steward\'s view of one account' do
    sign_in steward_user

    get "/#{locale}/billing/credit_accounts/#{account.id}"

    expect_ids(dom_id(account, :show_page), dom_id(account, :balance), dom_id(account, :lots), dom_id(account, :history), dom_id(lot))
  end

  it 'links to the credit screens from the orders list and the payment methods list' do
    sign_in buyer_user
    get "/#{locale}/billing/orders"
    expect_ids('billing-credit-link')

    sign_in steward_user
    get "/#{locale}/billing/processor_settings"
    expect_ids('billing-credit-accounts-link')
  end
end
