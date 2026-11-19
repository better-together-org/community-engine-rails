# frozen_string_literal: true

require 'rails_helper'

# Not run in normal CI (needs RUN_DOCS_SCREENSHOTS=1 and a browser):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 bundle exec prspec spec/docs_screenshots/better_together/billing_catalog_spec.rb'
# The identifiers it targets are locked by spec/dom_contracts/billing_catalog_spec.rb.
RSpec.describe 'Documentation screenshots for the public plan catalog', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  include_context 'with subscription fixtures'
  include_context 'with billing switched on'

  let(:free_attrs) { { processor: nil, processor_price_id: nil, processor_product_id: nil, amount_cents: 0, accepted_payment_methods: [] } }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    sub_plan.update!(listed: true, name: 'Supporting member', participant_summary: 'Support the work and vote at the AGM.')
    create(:better_together_billing_plan, :one_time, listed: true, name: 'Friend', participant_summary: 'Free, with no payment.', **free_attrs)
  end

  after { Current.platform = nil }

  it 'captures the catalog a visitor reads before signing in' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_catalog',
      device: :both,
      metadata: { locale: I18n.default_locale, role: 'visitor', feature_set: 'billing_catalog', flow: 'billing_catalog',
                  source_spec: self.class.metadata[:file_path] },
      callouts: [{ id: 'plans', selector: '#billing-catalog-plans', title: 'Listed plans',
                   bullets: ['Each plan shows its price and a button that starts checkout.'] }],
      narrative: {
        title: 'Plans',
        audience: %w[end_user],
        journey_step: 'As a visitor, I compare the plans on offer and choose one.',
        callouts: [{ id: 'plans', title: 'Plans', description: 'Price, summary and a Subscribe, Buy or Get it free button.' }],
        accessibility_notes: 'Each plan is an article with its own heading; buttons are links with plain text names.'
      }
    ) do
      visit "/#{I18n.default_locale}/billing/catalog"
      expect(page).to have_css('#billing-catalog-plans')
      page.execute_script("document.querySelector('#billing-catalog-plans').scrollIntoView({block: 'start'})")
    end
  end

  it 'captures one plan page' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_catalog_plan',
      device: :both,
      metadata: { locale: I18n.default_locale, role: 'visitor', feature_set: 'billing_catalog', flow: 'billing_catalog_plan',
                  source_spec: self.class.metadata[:file_path] },
      callouts: [{ id: 'buy', selector: "##{ActionView::RecordIdentifier.dom_id(sub_plan, :buy)}", title: 'Start checkout',
                   bullets: ['Sign-in is asked for at checkout, not before.'] }],
      narrative: {
        title: 'A plan',
        audience: %w[end_user],
        journey_step: 'As a visitor, I read about one plan and start checkout.',
        callouts: [{ id: 'buy', title: 'Subscribe', description: 'Leads to checkout for this plan.' }],
        accessibility_notes: 'The back link and the button have plain text names.'
      }
    ) do
      visit "/#{I18n.default_locale}/billing/catalog/#{sub_plan.id}"
      expect(page).to have_css('#billing-catalog-plan-page')
    end
  end
end
