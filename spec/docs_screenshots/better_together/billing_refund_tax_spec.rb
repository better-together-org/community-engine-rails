# frozen_string_literal: true

require 'rails_helper'

# Not run in normal CI (needs RUN_DOCS_SCREENSHOTS=1 and a browser):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 bundle exec prspec spec/docs_screenshots/better_together/billing_refund_tax_spec.rb'
# The identifiers it targets are locked by spec/dom_contracts/billing_offline_payments_spec.rb.
RSpec.describe 'Documentation screenshots for the tax on a refund', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  include_context 'with offline payment fixtures'
  include_context 'with billing switched on'

  let(:order) { place_offline('cash', tax_address: { country_iso: 'CA', region_code: 'NL' }) }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    create(:better_together_billing_tax_registration, platform: host_platform, country_iso: 'CA')
    zone = create(:better_together_billing_tax_zone, platform: host_platform, country_iso: 'CA', region_code: 'NL')
    create(:better_together_billing_tax_rate, platform: host_platform, tax_zone: zone, label: 'HST', rate: 0.15)
    transition.receive(offline_for(order), by: steward)
  end

  after { Current.platform = nil }

  it 'captures the refund form telling the seller how much tax the order carries' do
    payment = offline_for(order).payment
    note = "##{ActionView::RecordIdentifier.dom_id(payment, :refund_tax)}"

    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_refund_tax',
      device: :both,
      metadata: { locale: I18n.default_locale, role: 'platform_manager', feature_set: 'billing_tax', flow: 'billing_refund_tax',
                  source_spec: self.class.metadata[:file_path] },
      callouts: [{ id: 'tax-note', selector: "##{ActionView::RecordIdentifier.dom_id(payment, :refund)}", title: 'Tax in a refund',
                   avoid_container_selector: 'main',
                   bullets: ['Each refund carries its share of the order\'s tax, split from the net amount.'] }]
    ) do
      capybara_login_as_platform_manager
      visit "/#{I18n.default_locale}/billing/sales/#{order.id}"
      scroll_to(find(note), align: :center)
      expect(page).to have_css(note)
    end
  end
end
