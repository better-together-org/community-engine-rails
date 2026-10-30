# frozen_string_literal: true

require 'rails_helper'

# Not run in normal CI (needs RUN_DOCS_SCREENSHOTS=1 and a browser):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 bundle exec prspec spec/docs_screenshots/better_together/billing_plans_spec.rb'
# The identifiers it targets are locked by spec/dom_contracts/billing_plans_spec.rb.
RSpec.describe 'Documentation screenshots for billing plans', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  include_context 'with clean billing processors'
  include_context 'with billing switched on'

  let(:host_platform) { configure_host_platform }
  let(:adapter) { BetterTogether::Billing::FakeAdapter.new(capabilities: %i[plan_sync lookups]) }
  let!(:linked_plan) do
    create(:better_together_billing_plan, platform: host_platform, name: 'Hosted community', identifier: 'hosted-community',
                                          processor_price_id: 'price_pro_month', processor_product_id: 'prod_pro')
  end
  let!(:failed_plan) do
    create(:better_together_billing_plan, :unlinked, platform: host_platform, name: 'Supporter', identifier: 'supporter').tap do |plan|
      plan.record_sync_failure!('processor_unavailable')
    end
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    BetterTogether::Billing.register_processor(:fake, -> { adapter })
    Current.platform = host_platform
  end

  after { Current.platform = nil }

  def screenshot_metadata(flow:)
    { locale: I18n.default_locale, role: 'platform_manager', feature_set: 'billing_plans', flow:,
      source_spec: self.class.metadata[:file_path] }
  end

  def visit_plans(path = '')
    capybara_login_as_platform_manager
    visit "/#{I18n.default_locale}/billing/plans#{path}"
  end

  def open_select(container)
    expect(page).to have_css("#{container} select", visible: :all, wait: 10)
    expect(page).to have_css("#{container} .ss-main", wait: 5)
    find("#{container} .ss-main", match: :first).click
    expect(page).to have_css('.ss-content.ss-open, .ss-content .ss-option', wait: 10)
  end

  it 'captures the plans index with sync status' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_plans_index',
      device: :both,
      metadata: screenshot_metadata(flow: 'billing_plans_index'),
      callouts: [{ id: 'plans_table', selector: '#billing-plans-table', title: 'Plans',
                   bullets: ['Each plan is one price at the payment processor.'] },
                 { id: 'new_plan', selector: '#new-billing-plan-btn', title: 'New plan',
                   bullets: ['Create a plan here; no processor dashboard needed.'] }],
      narrative: {
        title: 'Billing plans',
        audience: %w[platform_organizer],
        journey_step: 'As a platform organizer, I see my platform\'s plans and whether each reached the processor.',
        callouts: [{ id: 'plans_table', title: 'Sync status',
                     description: 'A failed push shows here and can be retried from the plan page.' }],
        accessibility_notes: 'The table has column headers; status is text as well as colour.'
      }
    ) do
      visit_plans
      expect(page).to have_css('#billing-plans-table')
    end
  end

  it 'captures creating a plan, with the product list loaded from the processor' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_plans_new_create',
      device: :both,
      metadata: screenshot_metadata(flow: 'billing_plans_new_create'),
      callouts: [{ id: 'mode', selector: '#billing-plan-mode-tabs', title: 'Create or link',
                   bullets: ['Create a new price at the processor, or link one that exists.'] },
                 { id: 'product', selector: '#billing-plan-product-select', title: 'Product',
                   bullets: ['Options come live from the processor as you type.'] }],
      narrative: {
        title: 'Create a plan in the processor',
        audience: %w[platform_organizer],
        journey_step: 'As a platform organizer, I create a product and price from here.',
        callouts: [{ id: 'product', title: 'Processor-backed fields',
                     description: 'Product, currency and interval are fetched from the processor, not typed.' }],
        accessibility_notes: 'Selects have labels and keyboard support from SlimSelect.'
      }
    ) do
      visit_plans('/new')
      select 'fake', from: 'billing_plan_processor'
      open_select('#billing-plan-product-select')
      expect(page).to have_css('.ss-option', text: 'Pro (prod_pro)', wait: 10)
    end
  end

  it 'captures linking an existing price' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_plans_new_link',
      device: :both,
      metadata: screenshot_metadata(flow: 'billing_plans_new_link'),
      callouts: [{ id: 'price', selector: '#billing-plan-price-select', title: 'Existing price',
                   bullets: ['The amount, currency and interval are copied from the processor.'] }]
    ) do
      visit_plans('/new?mode=link')
      select 'fake', from: 'billing_plan_processor'
      open_select('#billing-plan-price-select')
      expect(page).to have_css('.ss-option', wait: 10)
    end
  end

  it 'captures a linked plan with its fixed fields and the live processor snapshot' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_plans_show_linked',
      device: :both,
      metadata: screenshot_metadata(flow: 'billing_plans_show_linked'),
      callouts: [{ id: 'locked', selector: '#billing-plan-locked-fields-note', title: 'Fixed fields',
                   bullets: ['The processor will not change these after creation.'] },
                 { id: 'snapshot', selector: '#billing-plan-processor-snapshot', title: 'Processor snapshot',
                   bullets: ['What the processor holds right now, with any drift flagged.'] },
                 { id: 'change_price', selector: '#billing-plan-change-price-btn', title: 'Change price',
                   bullets: ['Starts a new plan; the old price stays as it was.'] }]
    ) do
      visit_plans("/#{linked_plan.id}")
      expect(page).to have_css('#billing-plan-processor-snapshot', wait: 10)
      scroll_to(find('#billing-plan-locked-fields-note'), align: :center)
    end
  end

  it 'captures a failed push with its retry action' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_plans_show_failed',
      device: :both,
      metadata: screenshot_metadata(flow: 'billing_plans_show_failed'),
      callouts: [{ id: 'status', selector: '.billing-plan-sync-status-badge', title: 'Sync status',
                   bullets: ['A short reason is shown, never the processor\'s own text.'] },
                 { id: 'retry', selector: '#billing-plan-retry-sync-btn', title: 'Retry sync',
                   bullets: ['Queues the push again on the billing queue.'] }]
    ) do
      visit_plans("/#{failed_plan.id}")
      expect(page).to have_css('#billing-plan-retry-sync-btn')
    end
  end
end
