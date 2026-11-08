# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the billing plan screens: asserts the stable identifiers that
# documentation screenshots (spec/docs_screenshots/better_together/billing_plans_spec.rb)
# and downstream tooling target. Runs in normal CI (no RUN_DOCS_SCREENSHOTS gate).
RSpec.describe 'Billing plans DOM contract', :as_platform_manager, type: :request do # rubocop:disable RSpec/DescribeClass
  include_context 'with clean billing processors'
  include_context 'with billing switched on'

  let(:locale) { I18n.default_locale }
  let(:adapter) { BetterTogether::Billing::FakeAdapter.new(capabilities: %i[plan_sync lookups]) }
  let!(:plan) do
    BetterTogether::Billing.register_processor(:fake, -> { adapter })
    create(:better_together_billing_plan)
  end

  def expect_ids(*ids)
    ids.each { |id| expect(response.body).to include(%(id="#{id}")), "expected id=#{id.inspect} in the page" }
  end

  it 'exposes the index identifiers' do
    get "/#{locale}/billing/plans"

    expect(response).to have_http_status(:ok)
    expect_ids('billing-plans-index-page', 'billing-plans-table', 'new-billing-plan-btn', ActionView::RecordIdentifier.dom_id(plan),
               ActionView::RecordIdentifier.dom_id(plan, :actions))
    expect(response.body).to include('billing-plan-actions')
  end

  it 'exposes the accepted-payment-methods fieldset when a non-vendor method is installed' do
    cash = BetterTogether::Billing::FakeAdapter.new(capabilities: %i[offline_settlement], processor: :cash, settlement: :manual)
    BetterTogether::Billing.register_processor(:cash, -> { cash })

    get "/#{locale}/billing/plans/new"

    expect_ids('billing-plan-payment-methods', 'billing-plan-payment-method-cash')
  end

  it 'exposes the create-in-processor form identifiers' do
    get "/#{locale}/billing/plans/new"

    expect_ids('billing-plan-form', 'billing-plan-mode-tabs', 'billing-plan-mode-create', 'billing-plan-mode-link',
               'billing-plan-processor-fields', 'billing-plan-product-select', 'billing-plan-core-fields',
               'billing-plan-interval-select', 'billing-plan-currency-select', 'billing-plan-metadata-card',
               'billing-plan-form-actions')
  end

  it 'exposes the link-existing form identifiers' do
    get "/#{locale}/billing/plans/new", params: { mode: 'link' }

    expect_ids('billing-plan-form', 'billing-plan-price-select')
  end

  it 'exposes the linked-plan show identifiers, with the fields the processor fixed' do
    get "/#{locale}/billing/plans/#{plan.id}"
    dom_id = ActionView::RecordIdentifier

    expect(response).to have_http_status(:ok)
    expect_ids(dom_id.dom_id(plan, :show_page), dom_id.dom_id(plan, :summary_card), dom_id.dom_id(plan, :summary_details),
               dom_id.dom_id(plan, :price), dom_id.dom_id(plan, :processor_price_id), dom_id.dom_id(plan, :sync_status),
               dom_id.dom_id(plan, :sync_status_badge), dom_id.dom_id(plan, :actions), 'billing-plan-locked-fields-note',
               'billing-plan-change-price-btn', 'billing-plan-processor-snapshot')
    expect(response.body).to include('billing-plan-sync-status-badge')
  end

  it 'exposes the retry action only for a plan whose push failed' do
    plan.record_sync_failure!('processor_unavailable')

    get "/#{locale}/billing/plans/#{plan.id}"

    expect_ids('billing-plan-retry-sync-btn')
    expect(response.body).to include('billing-plan-sync-error')
  end

  it 'exposes the edit form with locked values in place of inputs' do
    get "/#{locale}/billing/plans/#{plan.id}/edit"

    expect_ids('billing-plan-form', 'billing-plan-locked-fields-note')
    expect(response.body).not_to include('name="billing_plan[amount_cents]"')
  end

  it 'exposes the snapshot frame contents' do
    get "/#{locale}/billing/plans/#{plan.id}/snapshot"

    expect(response).to have_http_status(:ok)
    expect_ids(ActionView::RecordIdentifier.dom_id(plan, :snapshot_details))
  end
end
