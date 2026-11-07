# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the promotion screens: the stable identifiers that documentation screenshots and
# downstream tooling target. Runs in normal CI (no RUN_DOCS_SCREENSHOTS gate).
RSpec.describe 'Billing promotions DOM contract', type: :request do # rubocop:disable RSpec/DescribeClass
  include_context 'with offline payment fixtures'
  include_context 'with billing switched on'

  let(:locale) { I18n.default_locale }
  let!(:made) do
    BetterTogether::Billing::Promotions::Create.call(platform: host_platform, actor: steward, name: 'Spring', amount_cents: 1500,
                                                     currency: 'USD')
  end

  def expect_ids(*ids)
    ids.each { |id| expect(response.body).to include(%(id="#{id}")), "expected id=#{id.inspect} in the page" }
  end

  def dom_id(*) = ActionView::RecordIdentifier.dom_id(*)

  it 'exposes the redeem form on a person\'s credit page' do
    sign_in buyer_user

    get "/#{locale}/billing/credit"

    expect_ids('billing-promotion-redeem-form', 'billing-promotion-code', 'billing-promotion-redeem-btn')
  end

  it 'exposes the steward\'s list: a row, a status badge and an action per promotion' do
    sign_in steward_user

    get "/#{locale}/billing/promotions"

    expect_ids('billing-promotions-page', 'billing-promotions-table', 'new-promotion-btn', dom_id(made.promotion),
               dom_id(made.promotion, :actions), dom_id(made.promotion, :deactivate_btn))
    expect(response.body).to include('promotion-status-badge')
  end

  it 'exposes the form fields' do
    sign_in steward_user

    get "/#{locale}/billing/promotions/new"

    expect_ids('billing-promotion-new-page', 'billing-promotion-form', 'billing-promotion-name', 'billing-promotion-amount',
               'billing-promotion-currency', 'billing-promotion-credit-days', 'billing-promotion-max', 'billing-promotion-starts',
               'billing-promotion-ends', 'billing-promotion-purposes', 'billing-promotion-new-members', 'billing-promotion-actions',
               'billing-promotion-save-btn')
  end

  it 'exposes the one-time code page' do
    sign_in steward_user

    post "/#{locale}/billing/promotions", params: { name: 'New', amount: '5', currency: 'USD' }

    expect_ids('billing-promotion-created-page', 'billing-promotion-code-warning', 'billing-promotion-code-display',
               'billing-promotion-done-btn')
  end

  it 'links to the promotions from the steward\'s credit accounts' do
    sign_in steward_user

    get "/#{locale}/billing/credit_accounts"

    expect_ids('billing-promotions-link')
  end
end
