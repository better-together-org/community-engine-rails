# frozen_string_literal: true

require 'rails_helper'

# Not run in normal CI (needs RUN_DOCS_SCREENSHOTS=1 and a browser):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 bundle exec prspec spec/docs_screenshots/better_together/billing_checkout_add_ons_spec.rb'
# The identifiers it targets are locked by spec/dom_contracts/billing_checkout_add_ons_spec.rb.
RSpec.describe 'Documentation screenshots for checkout add-ons', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  include_context 'with orders fixtures'
  include_context 'with builtin billing processors'
  include_context 'with billing switched on'

  let(:attrs) { { processor: nil, accepted_payment_methods: %w[cash], currency: 'USD' } }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    host_platform.billing_processor_settings.create!(processor: 'cash', enabled: true, acknowledge: true,
                                                     settings: { 'instructions' => 'At the hall' })
  end

  after { Current.platform = nil }

  it 'captures checkout with an add-on ticked' do
    plan = create(:better_together_billing_plan, :unlinked, :one_time, **attrs, name: 'Annual membership', amount_cents: 2500)
    add_on = create(:better_together_billing_plan, :unlinked, :one_time, **attrs, name: 'Conference lunch', amount_cents: 700, add_on: true)

    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_checkout_add_ons',
      device: :both,
      metadata: { locale: I18n.default_locale, role: 'user', feature_set: 'billing_checkout_add_ons', flow: 'billing_checkout_add_ons',
                  source_spec: self.class.metadata[:file_path] },
      callouts: [{ id: 'add_ons', selector: '#billing-checkout-add-ons', title: 'Add to your order',
                   bullets: ['Extras sold with this plan. Tick one and update the order to see the new total.'] },
                 { id: 'subtotal', selector: '#billing-checkout-subtotal', title: 'Subtotal',
                   bullets: ['The plan and every ticked extra, before tax.'] }],
      narrative: {
        title: 'Checkout with add-ons',
        audience: %w[end_user],
        journey_step: 'As a member buying a plan, I tick an extra and see it added to my order.',
        callouts: [{ id: 'add_ons', title: 'Add-ons', description: 'One-time extras paid by the local methods.' }],
        accessibility_notes: 'The extras are a labelled fieldset of checkboxes with a hint.'
      }
    ) do
      capybara_login_as_user
      visit "/#{I18n.default_locale}/billing/checkout/new?plan_id=#{plan.id}&add_on_ids[]=#{add_on.id}"
      expect(page).to have_css('#billing-checkout-add-ons')
      page.execute_script("document.querySelector('#billing-checkout-add-ons').scrollIntoView({block: 'center'})")
    end
  end
end
