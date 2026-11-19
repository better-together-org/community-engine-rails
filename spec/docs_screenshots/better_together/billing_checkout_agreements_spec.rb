# frozen_string_literal: true

require 'rails_helper'

# Not run in normal CI (needs RUN_DOCS_SCREENSHOTS=1 and a browser):
#   RUN_DOCS_SCREENSHOTS=1 bundle exec rspec --tag docs_screenshot \
#     spec/docs_screenshots/better_together/billing_checkout_agreements_spec.rb
# The identifiers it targets are locked by spec/dom_contracts/billing_checkout_agreements_spec.rb.
RSpec.describe 'Documentation screenshots for the checkout agreements', # rubocop:disable RSpec/SpecFilePathSuffix
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
  let(:identifiers) { %w[one_time_purchase_agreement offline_payment_terms] }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    host_platform.billing_processor_settings.create!(processor: 'cash', enabled: true, acknowledge: true,
                                                     settings: { 'instructions' => 'At the hall' })
    purchase_agreements_for(host_platform)
    create_billing_address_for(find_or_create_test_user('user@example.test').person)
  end

  after { Current.platform = nil }

  def read_and_tick(identifier) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    box = "#billing-agreement-accept-#{identifier}"
    find("#billing-agreement-view-#{identifier}").click
    expect(page).to have_css('#agreementModal.show #agreement_modal_frame', text: BetterTogether::Agreement.find_by!(identifier:).title,
                                                                            wait: 10)
    page.execute_script(<<~JS)
      const body = document.getElementById('agreement_modal_frame').closest('.modal-body');
      body.scrollTop = body.scrollHeight;
      body.dispatchEvent(new Event('scroll', { bubbles: true }));
    JS
    expect(page).to have_css("#{box}[data-better-together-agreement-enabled='true']", visible: :all, wait: 10)
    Timeout.timeout(10) do
      sleep 0.1 while page.evaluate_script('bootstrap.Modal.getInstance(document.getElementById("agreementModal"))._isTransitioning')
    end
    find('#agreementModal .modal-footer [data-bs-dismiss="modal"]').click
    expect(page).to have_no_css('#agreementModal.show', wait: 10)
    find(box).click
  end

  # Both agreements read and ticked, then the form refused for a blank new address: the page comes back with the ticks kept.
  def come_back_after_an_error # rubocop:disable Metrics/AbcSize
    capybara_login_as_user
    visit "/#{I18n.default_locale}/billing/checkout/new?plan_id=#{cash_plan.id}&payment_method=cash"
    identifiers.each { |identifier| read_and_tick(identifier) }
    page.execute_script("document.getElementById('billing-checkout-address-select').value = 'new'")
    click_button 'billing-checkout-place-btn'
    expect(page).to have_css('#billing-checkout-error', wait: 10)
    expect(page).to have_checked_field('billing-agreement-accept-one_time_purchase_agreement')
    page.execute_script("document.getElementById('billing-agreement-review').scrollIntoView({ block: 'center', behavior: 'instant' })")
  end

  def metadata(flow)
    { locale: I18n.default_locale, role: 'user', feature_set: 'billing_checkout_agreements', flow:,
      source_spec: self.class.metadata[:file_path] }
  end

  it 'captures the agreements still ticked after the form is refused' do # rubocop:disable RSpec/NoExpectationExample
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_checkout_ticks_kept',
      device: :both,
      metadata: metadata('billing_checkout_ticks_kept'),
      callouts: [{ id: 'ticked_box', selector: '#billing-agreement-accept-offline_payment_terms',
                   title: 'Still ticked', bullets: ['The buyer does not read each agreement again.'],
                   avoid_selectors: ['#billing-agreement-review'] }],
      narrative: {
        title: 'Checkout after an error',
        audience: %w[buyer],
        journey_step: 'As a buyer, I fix the address the form refused and place the order without re-reading the agreements.',
        callouts: [{ id: 'ticked_box', title: 'Still ticked', description: 'Boxes ticked before the error stay ticked and unlocked.' }],
        accessibility_notes: 'Each box keeps its label and its description; the error is an alert.'
      }
    ) { come_back_after_an_error }
  end

  it 'captures the same step without annotations' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_checkout_ticks_kept_plain',
      device: :both,
      metadata: metadata('billing_checkout_ticks_kept_plain')
    ) do
      come_back_after_an_error
      expect(page).to have_css('#billing-agreement-review')
    end
  end
end
