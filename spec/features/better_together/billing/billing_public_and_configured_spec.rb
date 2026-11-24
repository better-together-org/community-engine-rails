# frozen_string_literal: true

require 'rails_helper'

# The storefront on a public platform, and a platform that is set up the way a real deployment is: billing switched on
# and nothing else, then a steward turns on a method and the agreements, and a visitor can read the catalog.
RSpec.describe 'Billing on a public platform and a freshly configured one', :js, :no_auth, :skip_host_setup, retry: 0 do # rubocop:disable RSpec/DescribeClass
  include BetterTogether::CapybaraFeatureHelpers

  include_context 'with orders fixtures'
  include_context 'with clean billing processors'
  include_context 'with billing switched on'

  let(:locale) { I18n.default_locale }
  let(:wcag) { %i[wcag2a wcag2aa wcag21a wcag21aa] }
  let!(:listed_plan) do
    create(:better_together_billing_plan, :unlinked, processor: nil, accepted_payment_methods: %w[cash], billing_interval: 'month',
                                                     name: 'Public plan', currency: 'USD', amount_cents: 800, listed: true)
  end
  let!(:unlisted_plan) do
    create(:better_together_billing_plan, :unlinked, processor: nil, accepted_payment_methods: %w[cash], billing_interval: 'month',
                                                     name: 'Hidden plan', currency: 'USD', amount_cents: 900, listed: false)
  end

  before do
    BetterTogether.clear_adapters!(BetterTogether::Billing::ADAPTER_GROUP) # only the built-in methods, as on a real install
    BetterTogether::Billing.register_builtin_processors!
    Current.platform = host_platform
  end

  after { Current.platform = nil }

  def enable_cash_and_agreements
    host_platform.billing_processor_settings.create!(processor: 'cash', enabled: true, acknowledge: true,
                                                     settings: { 'instructions' => 'At the hall' })
    purchase_agreements_for(host_platform)
  end

  # Each activation sends the steward back to the billing page, so start from the requirements list every time.
  def activate_every_agreement
    10.times do
      visit "/#{locale}/billing/agreement_requirements"
      expect(page).to have_css('#billing-readiness-status', wait: 10)
      break unless page.has_css?("[id$='_activate']", wait: 2)

      find("[id$='_activate']", match: :first).click
      expect(page).to have_css('.alert', wait: 10)
    end
  end

  describe 'a public platform with billing configured' do
    before do
      host_platform.update!(privacy: 'public')
      enable_cash_and_agreements
    end

    it 'shows a visitor only the listed plans, and its detail page', :aggregate_failures do
      visit "/#{locale}/billing/catalog"

      expect(page).to have_content('Public plan')
      expect(page).to have_no_content('Hidden plan')
      expect(page).to be_axe_clean.within('main').according_to(*wcag).skipping('region')

      visit "/#{locale}/billing/catalog/#{listed_plan.id}"
      expect(page).to have_content('Public plan')
      expect(page).to have_content('US$8.00')
    end

    it 'does not reveal an unlisted plan', :aggregate_failures do
      visit "/#{locale}/billing/catalog/#{unlisted_plan.id}"

      expect(page).to have_no_content('Hidden plan')
      expect(page).to have_no_current_path(%r{/billing/checkout})
    end
  end

  describe 'a platform that has only had billing switched on' do
    before do
      host_platform.update!(privacy: 'public')
      host_platform.billing_processor_settings.destroy_all
    end

    it 'is a plain page not found to a visitor' do
      visit "/#{locale}/billing/catalog"

      expect(page).to have_no_content('Public plan')
      expect(page).to have_no_css('#billing-not-enabled-page')
    end

    it 'takes a steward from the not enabled page to a ready checklist and an open storefront', :aggregate_failures do # rubocop:disable RSpec/ExampleLength
      capybara_login_as_platform_manager
      visit "/#{locale}/billing/plans"
      expect(page).to have_css('#billing-not-enabled-method-enabled', wait: 10)

      click_link 'billing-not-enabled-settings-link'
      find('#billing-processor-edit-cash').click
      find('#billing-processor-setting-cash-instructions').set('Pay at the hall')
      find('#billing-processor-enable-cash').click
      find('#billing-processor-acknowledge').click
      find('#billing-processor-setting-save-btn').click
      expect(page).to have_no_css('#billing-processor-setting-form', wait: 10)
      expect(host_platform.billing_processor_settings.find_by(processor: 'cash')).to be_enabled

      BetterTogether::Billing::PurchaseAgreementSeeds.call(host_platform)
      activate_every_agreement
      visit "/#{locale}/billing/agreement_requirements"
      expect(page).to have_css('#billing-readiness-status', text: 'Ready', wait: 10)

      Capybara.reset_session!
      page.driver.browser.manage.delete_all_cookies
      visit "/#{locale}/billing/catalog"
      expect(page).to have_content('Public plan')
    end
  end
end
