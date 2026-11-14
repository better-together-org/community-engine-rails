# frozen_string_literal: true

require 'rails_helper'

# Not run in normal CI (needs RUN_DOCS_SCREENSHOTS=1 and a browser):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 WORKERS=1 bundle exec prspec spec/docs_screenshots/better_together/billing_plan_change_spec.rb'
# The identifiers it targets are locked by spec/dom_contracts/billing_subscriptions_spec.rb.
RSpec.describe 'Documentation screenshots for changing a plan', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  include_context 'with subscription fixtures'
  include_context 'with billing switched on'

  let(:host_platform) { configure_host_platform }
  let!(:bigger) do
    create(:better_together_billing_plan, name: 'Supporter', processor: nil, processor_price_id: nil, processor_product_id: nil,
                                          billing_interval: 'month', amount_cents: 5000, currency: 'USD',
                                          accepted_payment_methods: %w[cash store_credit], listed: true)
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
  end

  after { Current.platform = nil }

  def screenshot_metadata(flow:)
    { locale: I18n.default_locale, role: 'user', feature_set: 'billing_plan_change', flow:, source_spec: self.class.metadata[:file_path] }
  end

  def scroll_to_change
    page.execute_script("document.querySelector('#subscription-plan-change').scrollIntoView({block: 'center'})")
  end

  it 'captures choosing a new plan, now or from the next period' do
    term = start_subscription
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_plan_change_form',
      device: :both,
      metadata: screenshot_metadata(flow: 'billing_plan_change_form'),
      callouts: [{ id: 'when', selector: '#subscription-plan-change-when', title: 'When it starts',
                   bullets: ['From the next period changes nothing until then. Now is prorated and billed as an invoice.'] }],
      narrative: {
        title: 'Change plan',
        audience: %w[end_user],
        journey_step: 'As a subscriber, I pick another plan and choose whether it starts now or at the next period.',
        callouts: [{ id: 'when', title: 'When', description: 'The default is the next period, so nothing is charged early by accident.' }],
        accessibility_notes: 'The choices are a labelled radio group with a legend; the plan select has a label.'
      }
    ) do
      capybara_sign_in_user(buyer_user.email, password)
      visit "/#{I18n.default_locale}/billing/subscriptions/#{term.id}"
      expect(page).to have_css('#subscription-plan-change-when')
      scroll_to_change
    end
  end

  it 'captures a change made now, waiting for its invoice to be paid' do
    term = start_subscription
    travel_to(start_time + 10.days) { BetterTogether::Billing::Subscriptions::ChangePlan.now(term: term.reload, plan: bigger) }
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_plan_change_pending',
      device: :both,
      metadata: screenshot_metadata(flow: 'billing_plan_change_pending'),
      callouts: [{ id: 'invoice', selector: '#subscription-plan-change-invoice-link', title: 'Pay the difference',
                   bullets: ['The new plan starts once this invoice is paid. Withdraw the change to keep the current plan.'] }],
      narrative: {
        title: 'Change waiting for payment',
        audience: %w[end_user],
        journey_step: 'As a subscriber, I see the plan change is waiting on an invoice and can open it or withdraw.',
        callouts: [{ id: 'invoice', title: 'Invoice', description: 'Links to the prorated order.' }],
        accessibility_notes: 'The state is text, not colour; the link and the withdraw button are keyboard reachable.'
      }
    ) do
      capybara_sign_in_user(buyer_user.email, password)
      visit "/#{I18n.default_locale}/billing/subscriptions/#{term.id}"
      expect(page).to have_css('#subscription-plan-change-invoice-link')
      scroll_to_change
    end
  end
end
