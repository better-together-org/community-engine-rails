# frozen_string_literal: true

require 'rails_helper'

# Not run in normal CI (needs RUN_DOCS_SCREENSHOTS=1 and a browser):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 bundle exec prspec spec/docs_screenshots/better_together/billing_offline_payments_spec.rb'
# The identifiers it targets are locked by spec/dom_contracts/billing_offline_payments_spec.rb.
RSpec.describe 'Documentation screenshots for paying outside the platform', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  include_context 'with offline payment fixtures'

  let(:order) { place_offline('cash') }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    order
  end

  after { Current.platform = nil }

  def screenshot_metadata(flow:, role:)
    { locale: I18n.default_locale, role:, feature_set: 'billing_offline_payments', flow:, source_spec: self.class.metadata[:file_path] }
  end

  def visit_as_manager(path)
    capybara_login_as_platform_manager
    visit "/#{I18n.default_locale}/billing/#{path}"
  end

  it 'captures the buyer\'s pay screen' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_offline_pay_screen',
      device: :both,
      metadata: screenshot_metadata(flow: 'billing_offline_pay_screen', role: 'member'),
      callouts: [{ id: 'instructions', selector: '#billing-offline-instructions', title: 'How to pay',
                   bullets: ['Shown only on your own order, after you accepted the agreements.'] },
                 { id: 'disclosure', selector: '#billing-offline-disclosure', title: 'Before you pay',
                   bullets: ['What the platform cannot do for a payment made outside it.'] },
                 { id: 'claim', selector: '#billing-offline-claim-btn', title: 'I sent it',
                   bullets: ['Optional. The seller can confirm your payment either way.'] }],
      narrative: {
        title: 'Paying outside the platform',
        audience: %w[member],
        journey_step: 'As a member, I see how to pay the seller directly and what that means.',
        callouts: [{ id: 'claim', title: 'Telling the seller', description: 'You never have to; it only lets the seller know to look.' }],
        accessibility_notes: 'The disclosure is a note region; the claim field has a visible label.'
      }
    ) do
      capybara_sign_in_user(buyer_user.email, password)
      visit "/#{I18n.default_locale}/billing/orders/#{order.id}"
      scroll_to(find('#billing-offline-disclosure'), align: :center)
      expect(page).to have_css('#billing-offline-claim-btn')
    end
  end

  it 'captures the seller\'s queue with a claimed payment highlighted' do
    transition.claim(offline_for(order), reference: 'left it in the box')

    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_offline_queue',
      device: :both,
      metadata: screenshot_metadata(flow: 'billing_offline_queue', role: 'platform_manager'),
      callouts: [{ id: 'queue', selector: '#billing-offline-queue', title: 'Waiting for you',
                   bullets: ['Claimed payments come first and are marked.',
                             'Unclaimed ones are here too: confirm any of them when the money arrives.'] },
                 { id: 'confirm', selector: "#billing-offline-confirm-btn-#{order.id}", title: 'Mark received',
                   bullets: ['Does not need the buyer to have said anything.'] }]
    ) do
      visit_as_manager('offline_payments')
      scroll_to(find('#billing-offline-queue'), align: :center)
      expect(page).to have_css('.billing-offline-claimed-badge')
    end
  end

  it 'captures the seller\'s sale page with the confirm and reject forms' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_offline_sale',
      device: :both,
      metadata: screenshot_metadata(flow: 'billing_offline_sale', role: 'platform_manager'),
      callouts: [{ id: 'receive', selector: "#billing-offline-receive-form-#{order.id}", title: 'Say it arrived',
                   bullets: ['An optional reference and date; nothing is required.'] },
                 { id: 'reject', selector: "#billing-offline-reject-form-#{order.id}", title: 'Or say it did not',
                   bullets: ['The buyer sees your reason.'] }]
    ) do
      visit_as_manager("sales/#{order.id}")
      scroll_to(find("#billing-offline-receive-form-#{order.id}"), align: :center)
      expect(page).to have_css("#billing-offline-reject-btn-#{order.id}")
    end
  end

  it 'captures recording a sale in person' do
    plan
    purchase_agreements_for(host_platform)

    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_walk_up_sale',
      device: :both,
      metadata: screenshot_metadata(flow: 'billing_walk_up_sale', role: 'platform_manager'),
      callouts: [{ id: 'form', selector: '#billing-walk-up-form', title: 'A sale in person',
                   bullets: ['The buyer does nothing; they are told afterwards.'] },
                 { id: 'agreements', selector: '#billing-walk-up-agreements', title: 'Agreements',
                   bullets: ['Recorded as accepted in person, with you as the person who recorded it.'] }]
    ) do
      visit_as_manager('walk_up_sale/new')
      scroll_to(find('#billing-walk-up-form'), align: :center)
      expect(page).to have_css('#billing-walk-up-submit')
    end
  end
end
