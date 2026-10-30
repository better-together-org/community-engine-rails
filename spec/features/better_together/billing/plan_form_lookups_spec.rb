# frozen_string_literal: true

require 'rails_helper'

# The plan form's processor-backed selects load their options from the processor as the
# steward opens and types in them (SlimSelect + /billing/processor_options). Uses the fake
# adapter, so no vendor SDK is involved.
#
# Follows the layered-waiting pattern for SlimSelect (AGENTS.md): wait for the underlying
# <select>, then the SlimSelect wrapper, then interact.
RSpec.describe 'Billing plan form lookups', :accessibility, :js, :skip_host_setup, retry: 0 do
  include_context 'with clean billing processors'
  include_context 'with billing switched on'

  let(:adapter) { BetterTogether::Billing::FakeAdapter.new(capabilities: %i[plan_sync lookups]) }

  before do
    configure_host_platform
    BetterTogether::Billing.register_processor(:fake, -> { adapter })
    capybara_login_as_platform_manager
  end

  def open_select(container)
    expect(page).to have_css("#{container} select", visible: :all, wait: 10)
    expect(page).to have_css("#{container} .ss-main", wait: 5)
    find("#{container} .ss-main", match: :first).click
  end

  def pick(container, text)
    open_select(container)
    find('.ss-content .ss-option', text:, wait: 10).click
  end

  describe 'creating a plan in the processor' do
    before do
      visit "/#{I18n.default_locale}/billing/plans/new"
      select 'fake', from: 'billing_plan_processor'
    end

    it 'loads products from the processor when the select is opened' do
      open_select('#billing-plan-product-select')

      expect(page).to have_css('.ss-content .ss-option', text: 'Pro (prod_pro)', wait: 10)
      expect(page).to have_css('.ss-content .ss-option', text: 'Basic (prod_basic)')
    end

    it 'narrows the list as the steward types' do
      open_select('#billing-plan-product-select')
      find('.ss-content .ss-search input').set('basic')

      expect(page).to have_css('.ss-content .ss-option', text: 'Basic (prod_basic)', wait: 10)
      expect(page).to have_no_css('.ss-content .ss-option', text: 'Pro (prod_pro)')
    end

    it 'loads currencies and intervals the same way' do
      pick('#billing-plan-currency-select', 'CAD')
      pick('#billing-plan-interval-select', 'year')

      expect(page).to have_select('billing_plan_currency', selected: 'CAD', visible: :all)
      expect(page).to have_select('billing_plan_billing_interval', selected: 'year', visible: :all)
    end

    it 'passes WCAG 2.1 AA accessibility checks' do
      expect(page).to have_css('#billing-plan-product-select .ss-main', wait: 10)

      expect(page).to be_axe_clean
        .within('#billing-plan-form')
        .according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa)
    end
  end

  describe 'linking an existing price' do
    before do
      visit "/#{I18n.default_locale}/billing/plans/new?mode=link"
      select 'fake', from: 'billing_plan_processor'
    end

    it 'lists the processor prices' do
      open_select('#billing-plan-price-select')

      expect(page).to have_css('.ss-content .ss-option', text: 'USD 45.00 / month, Pro', wait: 10)
    end
  end

  describe 'when the processor cannot be reached' do
    before do
      visit "/#{I18n.default_locale}/billing/plans/new"
      select 'fake', from: 'billing_plan_processor'
    end

    it 'shows a message in the list instead of failing silently' do
      allow(adapter).to receive(:lookup).and_raise(BetterTogether::Billing::ProcessorAdapter::LookupError, 'down')

      open_select('#billing-plan-product-select')

      expect(page).to have_content(I18n.t('better_together.billing.plans.lookup_unavailable'), wait: 10)
    end
  end
end
