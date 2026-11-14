# frozen_string_literal: true

require 'rails_helper'

# The plan form takes the price as it is written (45.00), keeps what was typed when it is refused, and stays free of
# axe violations.
RSpec.describe 'Billing plan price entry', :accessibility, :js, :skip_host_setup, retry: 0 do
  include BetterTogether::CapybaraFeatureHelpers

  include_context 'with clean billing processors'
  include_context 'with billing switched on'

  let(:host_platform) { configure_host_platform }
  let(:adapter) { BetterTogether::Billing::FakeAdapter.new(capabilities: %i[plan_sync lookups]) }
  let(:wcag) { %i[wcag2a wcag2aa wcag21a wcag21aa wcag22aa] }
  let!(:plan) do
    create(:better_together_billing_plan, :unlinked, platform: host_platform, name: 'Garden plot', identifier: 'garden-plot',
                                                     amount_cents: 12_345, currency: 'USD')
  end

  before do
    BetterTogether::Billing.register_processor(:fake, -> { adapter })
    Current.platform = host_platform
    capybara_login_as_platform_manager
    visit "/#{I18n.default_locale}/billing/plans/#{plan.id}/edit"
  end

  after { Current.platform = nil }

  it 'shows the stored price as it is written and saves a changed one in cents' do
    expect(page).to have_field('billing_plan_amount', with: '123.45')

    fill_in 'billing_plan_amount', with: '99.99'
    click_button 'billing-plan-submit'

    expect(page).to have_current_path(%r{/billing/plans/#{plan.id}\z})
    expect(plan.reload.amount_cents).to eq(9999)
  end

  it 'explains a refused amount and keeps what was typed' do
    fill_in 'billing_plan_amount', with: '4.999'
    click_button 'billing-plan-submit'

    expect(page).to have_css('#billing-plan-errors', text: /decimal places/)
    expect(page).to have_field('billing_plan_amount', with: '4.999')
    expect(page).to have_css('#billing_plan_amount[aria-invalid="true"]')
    expect(plan.reload.amount_cents).to eq(12_345)
  end

  it 'has no axe violations on the form, including the refused state' do
    expect(page).to have_css('#billing-plan-form')
    expect(page).to be_axe_clean.according_to(*wcag).within('main')

    fill_in 'billing_plan_amount', with: 'abc'
    click_button 'billing-plan-submit'

    expect(page).to have_css('#billing-plan-errors')
    expect(page).to be_axe_clean.according_to(*wcag).within('main')
  end
end
