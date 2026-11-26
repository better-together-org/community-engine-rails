# frozen_string_literal: true

require 'rails_helper'

# Every billing screen, as the buyer and as a steward, passes an axe scan (WCAG 2.2 AA), so a label cut
# off from its field, or a control with no name, cannot come back unseen. One example per role: the
# setup and the sign-in are paid once, then each page is visited and scanned.
RSpec.describe 'Billing pages accessibility', :accessibility, :js, :skip_host_setup, retry: 0 do
  include_context 'with entitlement fixtures'
  include_context 'with billing switched on'

  let(:wcag_tags) { %i[wcag2a wcag2aa wcag21a wcag21aa wcag22aa] }

  let(:buyer_user) { find_or_create_test_user('user@example.test', password) }
  let(:locale) { I18n.default_locale }
  let!(:term) { start_subscription }
  let!(:order) { term.periods.first.order }

  before do
    configure_host_platform
    Capybara.reset_sessions!
    sub_plan.update!(listed: true)
    give_credit(2000)
    make_entitlement
    host_platform.billing_processor_settings.find_or_create_by!(processor: 'cash')
  end

  # The site search toggle in the shared navbar has an icon and no name; outside billing, so left for its own fix.
  def scan(path)
    visit "/#{locale}#{path}"
    expect(page).to have_current_path("/#{locale}#{path}", wait: 10)
    expect(page).to be_axe_clean.according_to(*wcag_tags).excluding('a[href$="#search"]')
  end

  it 'passes for the buyer', :aggregate_failures do # rubocop:disable RSpec/NoExpectationExample
    capybara_login_as_user
    plan_id = sub_plan.id
    %W[/billing /billing/catalog /billing/catalog/#{sub_plan.id} /billing/checkout/new?plan_id=#{plan_id}&payment_method=cash
       /billing/orders /billing/orders/#{order.id} /billing/subscriptions /billing/subscriptions/#{term.id}
       /billing/credit /billing/entitlements].each { |path| scan(path) }
  end

  it 'passes for a steward', :aggregate_failures do # rubocop:disable RSpec/NoExpectationExample
    capybara_login_as_platform_manager
    %W[/billing/plans /billing/plans/new /billing/plans/#{sub_plan.id} /billing/plans/#{sub_plan.id}/edit
       /billing/processor_settings /billing/processor_settings/cash/edit /billing/sales /billing/sales/#{order.id}
       /billing/subscribers /billing/subscribers/#{term.id} /billing/promotions /billing/promotions/new
       /billing/tax_registrations /billing/tax_registrations/new /billing/agreement_requirements
       /billing/offline_payments /billing/walk_up_sale/new /billing/credit_accounts /billing/allowances
       /host/metrics/billing_reports /host/metrics/billing_reports/new /host/metrics/reports].each { |path| scan(path) }
  end
end
