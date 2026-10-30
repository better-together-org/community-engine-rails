# frozen_string_literal: true

require 'rails_helper'

# Not run in normal CI (needs RUN_DOCS_SCREENSHOTS=1 and a browser):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 bundle exec prspec spec/docs_screenshots/better_together/billing_processor_settings_spec.rb'
# The identifiers it targets are locked by spec/dom_contracts/billing_processor_settings_spec.rb.
RSpec.describe 'Documentation screenshots for payment methods', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  include_context 'with clean billing processors'
  include_context 'with builtin billing processors'
  include_context 'with billing switched on'

  let(:host_platform) { configure_host_platform }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    host_platform.billing_processor_settings.create!(processor: 'cash', enabled: true, acknowledge: true,
                                                     settings: { 'instructions' => 'At the community hall, Saturdays 10 to noon' })
  end

  after { Current.platform = nil }

  def screenshot_metadata(flow:)
    { locale: I18n.default_locale, role: 'platform_manager', feature_set: 'billing_payment_methods', flow:,
      source_spec: self.class.metadata[:file_path] }
  end

  def visit_settings(path = '')
    capybara_login_as_platform_manager
    visit "/#{I18n.default_locale}/billing/processor_settings#{path}"
  end

  it 'captures the list of payment methods and their state' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_processor_settings_index',
      device: :both,
      metadata: screenshot_metadata(flow: 'billing_processor_settings_index'),
      callouts: [{ id: 'methods', selector: '#billing-processor-settings-table', title: 'Payment methods',
                   bullets: ['Cash, cheque and e-transfer are installed for everyone and off until you turn them on.'] },
                 { id: 'etransfer_where', selector: '#billing-processor-setting-etransfer', title: 'Where it works',
                   bullets: ['E-transfer works only in Canada, in Canadian dollars.'] }],
      narrative: {
        title: 'Payment methods',
        audience: %w[platform_organizer],
        journey_step: 'As a platform organizer, I see which ways to be paid outside a processor are on for my platform.',
        callouts: [{ id: 'methods', title: 'Status', description: 'Each row shows whether the method is on, off or not set up yet.' }],
        accessibility_notes: 'The table has column headers; the state is text as well as colour.'
      }
    ) do
      visit_settings
      expect(page).to have_css('#billing-processor-settings-table')
    end
  end

  it 'captures turning cash on, with the drawbacks to accept' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_processor_settings_cash',
      device: :both,
      metadata: screenshot_metadata(flow: 'billing_processor_settings_cash'),
      callouts: [{ id: 'instructions', selector: '#billing-processor-setting-fields', title: 'What buyers are told',
                   bullets: ['Shown only on a buyer\'s own order, after they accept the terms. Stored encrypted.'] },
                 { id: 'disclosure', selector: '#billing-processor-disclosure', title: 'The drawbacks',
                   bullets: ['No fee can be collected, nothing is tracked, and buyers have no dispute protection.'] },
                 { id: 'enable', selector: '#billing-processor-enable-cash', title: 'Turn it on',
                   bullets: ['Off until you accept the drawbacks.'] }]
    ) do
      visit_settings('/cash/edit')
      scroll_to(find('#billing-processor-disclosure'), align: :center)
      expect(page).to have_css('#billing-processor-enable-cash')
    end
  end

  it 'captures the cheque form with the choice of when access starts' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_processor_settings_cheque',
      device: :both,
      metadata: screenshot_metadata(flow: 'billing_processor_settings_cheque'),
      callouts: [{ id: 'grant_on', selector: '#billing-processor-grant-on', title: 'When access starts',
                   bullets: ['A cheque can bounce, so waiting until it clears is the safer default.'] }]
    ) do
      visit_settings('/cheque/edit')
      expect(page).to have_css('#billing-processor-grant-on')
    end
  end

  it 'captures the e-transfer form and its country limit' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_processor_settings_etransfer',
      device: :both,
      metadata: screenshot_metadata(flow: 'billing_processor_settings_etransfer'),
      callouts: [{ id: 'recipient', selector: '#billing-processor-setting-fields', title: 'Where buyers send it',
                   bullets: ['An email address or a phone number, so buyers know where to send the e-transfer.'] },
                 { id: 'disclosure', selector: '#billing-processor-disclosure', title: 'Canada only',
                   bullets: ['Available in Canada, in Canadian dollars.'] }]
    ) do
      visit_settings('/etransfer/edit')
      expect(page).to have_css('#billing-processor-setting-etransfer-recipient_email')
    end
  end
end
