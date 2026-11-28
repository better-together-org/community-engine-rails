# frozen_string_literal: true

require 'rails_helper'

# Not run in normal CI (needs RUN_DOCS_SCREENSHOTS=1 and a browser):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 bundle exec prspec spec/docs_screenshots/better_together/billing_price_choice_spec.rb'
# The identifiers it targets are locked by spec/dom_contracts/billing_catalog_spec.rb.
RSpec.describe 'Documentation screenshots for choosing a price', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  include_context 'with subscription fixtures'
  include_context 'with billing switched on'

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    sub_plan.update!(listed: true, name: 'Supporting member', participant_summary: 'Support the work and vote at the AGM.')
    create(:better_together_billing_price, product: sub_plan, platform: sub_plan.platform, kind: 'recurring', interval: 'year',
                                           amount_cents: 30_000, currency: 'USD', label: 'Pay once a year')
  end

  after { Current.platform = nil }

  it 'captures a plan page that offers a monthly and a yearly price' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_price_choice',
      device: :both,
      metadata: { locale: I18n.default_locale, role: 'visitor', feature_set: 'billing_catalog', flow: 'billing_price_choice',
                  source_spec: self.class.metadata[:file_path] },
      callouts: [{ id: 'prices', selector: "##{ActionView::RecordIdentifier.dom_id(sub_plan, :catalog_prices)}", title: 'Choose a price',
                   bullets: ['Each price has its own button into checkout.'] }],
      narrative: {
        title: 'Choosing a price',
        audience: %w[end_user],
        journey_step: 'As a buyer, I pick the monthly or the yearly price of one plan.',
        callouts: [{ id: 'prices', title: 'Prices', description: 'One row per price with a Subscribe button.' }],
        accessibility_notes: 'Each button repeats the plan name and price for screen readers.'
      }
    ) do
      visit "/#{I18n.default_locale}/billing/catalog/#{sub_plan.id}"
      dom = ActionView::RecordIdentifier.dom_id(sub_plan, :catalog_prices)
      expect(page).to have_css("##{dom}")
      page.execute_script("document.getElementById('#{dom}').scrollIntoView({block: 'center'})")
    end
  end
end
