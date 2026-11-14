# frozen_string_literal: true

require 'rails_helper'

# Not run in normal CI (needs RUN_DOCS_SCREENSHOTS=1 and a browser):
#   RUN_DOCS_SCREENSHOTS=1 bundle exec rspec --tag docs_screenshot \
#     spec/docs_screenshots/better_together/billing_agreement_reader_spec.rb
# The identifiers it targets are locked by spec/dom_contracts/billing_agreement_reader_spec.rb.
RSpec.describe 'Documentation screenshots for the agreement reader', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers
  include BetterTogether::BillingAddressHelpers

  include_context 'with orders fixtures'
  include_context 'with builtin billing processors'
  include_context 'with billing switched on'

  let(:cash_plan) do
    create(:better_together_billing_plan, :unlinked, processor: nil, accepted_payment_methods: %w[cash], billing_interval: 'one_time',
                                                     name: 'Garden plot', currency: 'USD', amount_cents: 2500)
  end
  let(:identifier) { 'one_time_purchase_agreement' }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    host_platform.billing_processor_settings.create!(processor: 'cash', enabled: true, acknowledge: true,
                                                     settings: { 'instructions' => 'At the hall' })
    purchase_agreements_for(host_platform)
    create_billing_address_for(find_or_create_test_user('user@example.test').person)
  end

  after { Current.platform = nil }

  def settle
    Timeout.timeout(10) do
      sleep 0.1 while page.evaluate_script('bootstrap.Modal.getInstance(document.getElementById("agreementModal"))._isTransitioning')
    end
  end

  def open_reader_with_keyboard # rubocop:disable Metrics/AbcSize
    capybara_login_as_user
    visit "/#{I18n.default_locale}/billing/checkout/new?plan_id=#{cash_plan.id}&payment_method=cash"
    page.execute_script("document.getElementById('billing-agreement-view-#{identifier}').focus()")
    page.send_keys(:enter)
    expect(page).to have_css('#agreementModal.show #agreement_modal_frame', text: BetterTogether::Agreement.find_by!(identifier:).title,
                                                                            wait: 10)
    settle
  end

  def read_to_the_end_and_close # rubocop:disable Metrics/AbcSize
    page.execute_script(<<~JS)
      const body = document.getElementById('agreement-modal-body');
      body.scrollTop = body.scrollHeight;
      body.dispatchEvent(new Event('scroll', { bubbles: true }));
    JS
    expect(page).to have_css("#billing-agreement-accept-#{identifier}[data-better-together-agreement-enabled='true']", visible: :all, wait: 10)
    page.send_keys(:escape)
    expect(page).to have_no_css('#agreementModal.show', wait: 10)
    expect(page).to have_css("#billing-agreement-view-#{identifier}:focus", wait: 10)
    page.send_keys(:tab)
    expect(page).to have_css("#billing-agreement-accept-#{identifier}:focus")
  end

  def metadata(flow)
    { locale: I18n.default_locale, role: 'user', feature_set: 'billing_agreement_reader', flow:, source_spec: self.class.metadata[:file_path] }
  end

  it 'captures the reader opened from the keyboard, with focus on the text' do # rubocop:disable RSpec/NoExpectationExample
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_agreement_reader_open',
      device: :both,
      metadata: metadata('billing_agreement_reader_open'),
      callouts: [{ id: 'reader_text', selector: '#agreement-modal-body',
                   title: 'Focus starts on the text', bullets: ['Arrow and page keys scroll it.', 'Escape closes the reader.'] }],
      narrative: {
        title: 'Agreement reader opened with Enter or Space',
        audience: %w[buyer],
        journey_step: 'As a buyer using only the keyboard, I open an agreement and read it.',
        callouts: [{ id: 'reader_text', title: 'Focus starts on the text',
                     description: 'The text region is focusable, so the keyboard can scroll it.' }],
        accessibility_notes: 'The dialog is named after the agreement; Tab stays inside it; Escape closes it and focus returns to the link.'
      }
    ) { open_reader_with_keyboard }
  end

  it 'captures the reader opened from the keyboard without annotations' do # rubocop:disable RSpec/NoExpectationExample
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_agreement_reader_open_plain', device: :both, metadata: metadata('billing_agreement_reader_open_plain')
    ) do
      open_reader_with_keyboard
      expect(page).to have_css('#agreement-modal-body:focus')
    end
  end

  it 'captures the box unlocked and focused after the reader is closed with Escape' do # rubocop:disable RSpec/NoExpectationExample
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_agreement_reader_unlocked',
      device: :both,
      metadata: metadata('billing_agreement_reader_unlocked'),
      callouts: [{ id: 'unlocked_box', selector: "#billing-agreement-accept-#{identifier}",
                   title: 'Unlocked and next in line', bullets: ['Tab reaches the box; Space ticks it.'],
                   avoid_selectors: ['#billing-agreement-review'] }],
      narrative: {
        title: 'Box unlocked after reading',
        audience: %w[buyer],
        journey_step: 'As a buyer using only the keyboard, I close the reader and tick the box it unlocked.',
        callouts: [{ id: 'unlocked_box', title: 'Unlocked and next in line',
                     description: 'Focus returned to the link, so one Tab reaches the box.' }],
        accessibility_notes: 'Reading to the end is announced through a polite status message; focus is never moved without the buyer acting.'
      }
    ) do
      open_reader_with_keyboard
      read_to_the_end_and_close
      page.execute_script("document.getElementById('billing-agreement-review').scrollIntoView({ block: 'center', behavior: 'instant' })")
    end
  end

  it 'captures the unlocked box without annotations' do # rubocop:disable RSpec/NoExpectationExample
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_agreement_reader_unlocked_plain', device: :both, metadata: metadata('billing_agreement_reader_unlocked_plain')
    ) do
      open_reader_with_keyboard
      read_to_the_end_and_close
      page.execute_script("document.getElementById('billing-agreement-review').scrollIntoView({ block: 'center', behavior: 'instant' })")
    end
  end
end
