# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the entitlement screens: the stable identifiers that documentation screenshots and downstream
# tooling target. Runs in normal CI (no RUN_DOCS_SCREENSHOTS gate).
RSpec.describe 'Billing entitlements DOM contract', type: :request do # rubocop:disable RSpec/DescribeClass
  include_context 'with entitlement fixtures'
  include_context 'with billing switched on'

  let(:locale) { I18n.default_locale }

  before do
    role_grant
    quota_grant
  end

  def expect_ids(*ids)
    ids.each { |id| expect(response.body).to include(%(id="#{id}")), "expected id=#{id.inspect} in the page" }
  end

  def dom_id(*) = ActionView::RecordIdentifier.dom_id(*)

  it 'exposes the holder\'s access: an entitlement, its allowances and a meter' do
    entitlement = entitlement_for(start_subscription)
    sign_in buyer_user

    get "/#{locale}/billing/entitlements"

    expect_ids('billing-entitlements-page', dom_id(entitlement), dom_id(entitlement, :heading), dom_id(entitlement, :for),
               dom_id(entitlement, :allowances),
               dom_id(entitlement.grants.applied.allowances.first))
    expect(response.body).to include('entitlement-status-badge')
  end

  it 'exposes the steward\'s allowances page: a form per quota type and the usage table' do
    entitlement_for(start_subscription)
    sign_in steward_user

    get "/#{locale}/billing/allowances"

    expect_ids('billing-allowances-page', 'billing-allowances-enforcement', 'billing-allowance-type-media_storage',
               'billing-allowance-form-media_storage',
               'billing-allowance-mode-media_storage', 'billing-allowance-save-media_storage', 'billing-allowances-table')
  end

  it 'exposes what a plan includes, with a form per kind' do
    grant = sub_plan.plan_grants.first
    sign_in steward_user

    get "/#{locale}/billing/plans/#{sub_plan.id}"

    expect_ids(dom_id(sub_plan, :grants), dom_id(sub_plan, :grants_list), dom_id(grant), dom_id(grant, :remove_btn), 'billing-grant-role-form',
               'billing-grant-role-joinable', 'billing-grant-role-community', 'billing-grant-role-role', 'billing-grant-role-btn',
               'billing-grant-feature-form', 'billing-grant-feature-key', 'billing-grant-feature-level', 'billing-grant-feature-btn',
               'billing-grant-quota-form', 'billing-grant-quota-type', 'billing-grant-quota-amount', 'billing-grant-quota-btn')
  end

  it 'links to them from the orders list and the payment methods list' do
    sign_in buyer_user
    get "/#{locale}/billing/orders"
    expect_ids('billing-entitlements-link')

    sign_in steward_user
    get "/#{locale}/billing/processor_settings"
    expect_ids('billing-allowances-link')
  end
end
