# frozen_string_literal: true

require 'rails_helper'

# DOM contract for checkout and the purchase terms screens: asserts the stable identifiers that
# documentation screenshots (spec/docs_screenshots/better_together/billing_checkout_spec.rb) and
# downstream tooling target. Runs in normal CI (no RUN_DOCS_SCREENSHOTS gate).
RSpec.describe 'Billing checkout DOM contract', :as_platform_manager, type: :request do # rubocop:disable RSpec/DescribeClass
  include_context 'with orders fixtures'
  include_context 'with builtin billing processors'
  include_context 'with billing switched on'

  let(:locale) { I18n.default_locale }
  let(:cash_plan) do
    create(:better_together_billing_plan, :unlinked, processor: nil, accepted_payment_methods: %w[cash], billing_interval: 'one_time',
                                                     currency: 'USD', amount_cents: 2500)
  end

  def one_time_agreement = BetterTogether::Agreement.billing_record('one_time_purchase_agreement', platform: host_platform)

  def expect_ids(*ids)
    ids.each { |id| expect(response.body).to include(%(id="#{id}")), "expected id=#{id.inspect} in the page" }
  end

  before do
    host_platform.billing_processor_settings.create!(processor: 'cash', enabled: true, acknowledge: true,
                                                     settings: { 'instructions' => 'At the hall' })
    purchase_agreements_for(host_platform)
  end

  it 'exposes the method choice' do
    get "/#{locale}/billing/checkout/new", params: { plan_id: cash_plan.id }

    expect_ids('billing-checkout-page', 'billing-checkout-summary', 'billing-checkout-method-form', 'billing-checkout-methods',
               'billing-checkout-method-cash', 'billing-checkout-continue-btn')
  end

  it 'exposes the review and accept step' do
    get "/#{locale}/billing/checkout/new", params: { plan_id: cash_plan.id, payment_method: 'cash' }

    expect_ids('billing-checkout-form', 'billing-agreement-review', 'billing-agreement-accept-one_time_purchase_agreement',
               'billing-agreement-accept-offline_payment_terms', 'billing-checkout-place-btn',
               ActionView::RecordIdentifier.dom_id(one_time_agreement, :review))
  end

  it 'exposes the reason a method is unavailable' do
    host_platform.billing_processor_settings.find_by(processor: 'cash').update!(purposes: %w[ticket])

    get "/#{locale}/billing/checkout/new", params: { plan_id: cash_plan.id }

    expect_ids('billing-checkout-method-cash-reason', 'billing-checkout-no-methods')
  end

  it 'exposes the not-ready message instead of the form when the agreements are drafts' do
    BetterTogether::Billing::PurchaseAgreementSeeds.call(host_platform).each_value { |agreement| agreement.update!(lifecycle_state: 'draft') }

    get "/#{locale}/billing/checkout/new", params: { plan_id: cash_plan.id, payment_method: 'cash' }

    expect_ids('billing-checkout-not-ready')
  end

  it 'exposes the error message when the order is refused' do
    post "/#{locale}/billing/checkout", params: { plan_id: cash_plan.id, payment_method: 'cash', accepted_agreement_ids: [] }

    expect_ids('billing-checkout-error')
  end

  it 'exposes the purchase terms page, the checklist and the form' do
    get "/#{locale}/billing/agreement_requirements"

    expect_ids('billing-agreement-requirements-page', 'billing-agreement-requirements-table', 'billing-readiness-checklist',
               'billing-readiness-status',
               'billing-readiness-configured', 'billing-readiness-method_enabled', 'billing-readiness-agreements-subscription',
               'billing-readiness-agreements-one_time', 'billing-agreement-requirement-form', 'billing-requirement-agreement',
               'billing-requirement-plan', 'billing-requirement-purpose', 'billing-requirement-method', 'billing-requirement-mode',
               'billing-requirement-add-btn')
  end

  it 'exposes the checklist on the payment methods page, with a link to the purchase terms' do
    get "/#{locale}/billing/processor_settings"

    expect_ids('billing-readiness-checklist', 'billing-purchase-terms-link')
  end

  it 'exposes the agreements on an order' do
    order = place_order(buyer: BetterTogether::User.find_by!(email: 'manager@example.test').person)

    get "/#{locale}/billing/orders/#{order.id}"

    expect_ids('billing-order-agreements', ActionView::RecordIdentifier.dom_id(order.agreement_acceptances.first))
  end
end
