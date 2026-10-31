# frozen_string_literal: true

require 'rails_helper'

# Not run in normal CI (needs RUN_DOCS_SCREENSHOTS=1 and a browser):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 bundle exec prspec spec/docs_screenshots/better_together/billing_checkout_spec.rb'
# The identifiers it targets are locked by spec/dom_contracts/billing_checkout_spec.rb.
RSpec.describe 'Documentation screenshots for checkout and purchase terms', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  include_context 'with orders fixtures'
  include_context 'with builtin billing processors'
  include_context 'with billing switched on'

  let(:cash_plan) do
    create(:better_together_billing_plan, :unlinked, processor: nil, accepted_payment_methods: %w[cash], billing_interval: 'one_time',
                                                     name: 'Garden plot', currency: 'USD', amount_cents: 2500)
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    host_platform.billing_processor_settings.create!(processor: 'cash', enabled: true, acknowledge: true,
                                                     settings: { 'instructions' => 'At the hall' })
    purchase_agreements_for(host_platform)
  end

  after { Current.platform = nil }

  def screenshot_metadata(flow:)
    { locale: I18n.default_locale, role: 'platform_manager', feature_set: 'billing_checkout', flow:,
      source_spec: self.class.metadata[:file_path] }
  end

  def visit_billing(path)
    capybara_login_as_platform_manager
    visit "/#{I18n.default_locale}/billing/#{path}"
  end

  it 'captures choosing how to pay' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_checkout_methods',
      device: :both,
      metadata: screenshot_metadata(flow: 'billing_checkout_methods'),
      callouts: [{ id: 'summary', selector: '#billing-checkout-summary', title: 'What you are buying', bullets: ['The plan and its price.'] },
                 { id: 'methods', selector: '#billing-checkout-methods', title: 'Ways to pay',
                   bullets: ['A method that is not available says why.'] }],
      narrative: {
        title: 'Checkout: how to pay',
        audience: %w[member],
        journey_step: 'As a member, I choose how I want to pay.',
        callouts: [{ id: 'methods', title: 'Choose a method', description: 'Only ways the seller has switched on can be chosen.' }],
        accessibility_notes: 'Options are radio buttons with labels; unavailable ones are disabled and explained in text.'
      }
    ) do
      visit_billing("checkout/new?plan_id=#{cash_plan.id}")
      expect(page).to have_css('#billing-checkout-methods')
    end
  end

  it 'captures reviewing and accepting the agreements before placing the order' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_checkout_agreements',
      device: :both,
      metadata: screenshot_metadata(flow: 'billing_checkout_agreements'),
      callouts: [{ id: 'review', selector: '#billing-agreement-review', title: 'Review and accept',
                   bullets: ['The purchase terms and the terms that come with this way of paying.'] },
                 { id: 'place', selector: '#billing-checkout-place-btn', title: 'Place order',
                   bullets: ['Nothing is placed until every agreement is accepted.'] }]
    ) do
      visit_billing("checkout/new?plan_id=#{cash_plan.id}&payment_method=cash")
      scroll_to(find('#billing-agreement-review'), align: :center)
      expect(page).to have_css('#billing-checkout-place-btn')
    end
  end

  it 'captures the steward\'s purchase terms and the readiness checklist' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_purchase_terms',
      device: :both,
      metadata: screenshot_metadata(flow: 'billing_purchase_terms'),
      callouts: [{ id: 'checklist', selector: '#billing-readiness-checklist', title: 'Ready to sell?',
                   bullets: ['Draft agreements keep the platform from selling until they are reviewed and set to active.'] },
                 { id: 'table', selector: '#billing-agreement-requirements-table', title: 'Requirements',
                   bullets: ['Defaults apply to everything; a plan or a payment method can add its own.'] },
                 { id: 'form', selector: '#billing-agreement-requirement-form', title: 'Add a requirement',
                   bullets: ['Pick an agreement and what it applies to.'] }]
    ) do
      visit_billing('agreement_requirements')
      expect(page).to have_css('#billing-readiness-checklist')
    end
  end
end
