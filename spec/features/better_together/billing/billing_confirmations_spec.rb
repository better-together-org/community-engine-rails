# frozen_string_literal: true

require 'rails_helper'

# The confirmation asked before a steward moves money: it names the order, the buyer and the amount typed, can be
# cancelled, and the pages stay free of axe violations.
RSpec.describe 'Billing steward confirmations', :accessibility, :js, :skip_host_setup, retry: 0 do
  include BetterTogether::CapybaraFeatureHelpers

  include_context 'with offline payment fixtures'
  include_context 'with billing switched on'

  let(:order) { place_offline('cash') }
  let(:offline) { offline_for(order) }
  let(:payment) { offline.payment }
  let(:wcag) { %i[wcag2a wcag2aa wcag21a wcag21aa wcag22aa] }

  before do
    Current.platform = host_platform
    transition.receive(offline, by: steward)
    capybara_login_as_platform_manager
  end

  after { Current.platform = nil }

  describe 'recording a refund' do
    before do
      visit "/#{I18n.default_locale}/billing/sales/#{order.id}"
      fill_in "refund_amount_#{offline.id}", with: '12.50'
    end

    it 'names the amount typed and records the refund once confirmed' do
      accept_confirm(/12\.50 USD.*#{order.number}/m) { click_button "billing-sale-refund-btn-#{offline.id}" }

      expect(page).to have_css('.alert', text: /Refund recorded/i)
      expect(payment.reload.refunds.sole.amount_cents).to eq(1250)
    end

    it 'records nothing when the steward cancels' do
      dismiss_confirm { click_button "billing-sale-refund-btn-#{offline.id}" }

      expect(page).to have_css("#billing-sale-refund-form-#{offline.id}")
      expect(payment.reload.refunds).to be_empty
    end

    it 'falls back to the full amount when the field is emptied' do
      fill_in "refund_amount_#{offline.id}", with: ''

      message = dismiss_confirm(/45\.00/) { click_button "billing-sale-refund-btn-#{offline.id}" }

      expect(message).to include(order.number)
    end
  end

  it 'has no axe violations on a sale with its confirmable forms' do
    visit "/#{I18n.default_locale}/billing/sales/#{order.id}"

    expect(page).to have_css("#billing-sale-refund-form-#{offline.id}")
    expect(page).to be_axe_clean.according_to(*wcag).within('main')
  end

  it 'has no axe violations on the payments queue' do
    other = place_offline('cash')
    transition.claim(offline_for(other), reference: 'sent')
    visit "/#{I18n.default_locale}/billing/offline_payments"

    expect(page).to have_css('#billing-offline-queue')
    expect(page).to be_axe_clean.according_to(*wcag).within('main')
  end

  it 'asks before giving store credit and has no axe violations on the grant form' do
    create(:better_together_person_platform_membership, joinable: host_platform, member: buyer)
    visit "/#{I18n.default_locale}/billing/credit_accounts?person_id=#{buyer.id}"
    fill_in 'billing-credit-grant-amount', with: '20'

    expect(page).to be_axe_clean.according_to(*wcag).within('main')
    dismiss_confirm(/20 [A-Z]{3}.*#{Regexp.escape(buyer.name)}/m) { click_button 'billing-credit-grant-btn' }
  end
end
