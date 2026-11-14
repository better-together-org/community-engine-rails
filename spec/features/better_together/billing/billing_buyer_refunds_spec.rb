# frozen_string_literal: true

require 'rails_helper'

# The refunds a buyer sees on their own order and on their billing page, free of axe violations.
RSpec.describe 'Billing refunds seen by the buyer', :accessibility, :js, :skip_host_setup, retry: 0 do
  include BetterTogether::CapybaraFeatureHelpers

  include_context 'with offline payment fixtures'
  include_context 'with billing switched on'

  let(:buyer_user) { find_or_create_test_user('user@example.test') }
  let(:order) { place_offline('cash') }
  let(:wcag) { %i[wcag2a wcag2aa wcag21a wcag21aa wcag22aa] }
  let!(:refund) do
    Current.platform = host_platform
    transition.receive(offline_for(order), by: steward)
    BetterTogether::Billing::Refunds::Record.call(payment: offline_for(order).payment, amount_cents: 1250, idempotency_key: 'one',
                                                  reason: 'requested_by_buyer', recorded_by: steward)
  end

  before do
    refund.update_columns(created_at: Time.utc(2026, 6, 15, 16)) # rubocop:disable Rails/SkipsModelValidations
    capybara_login_as_user
  end

  after { Current.platform = nil }

  it 'lists the refund on the order with its amount, date and status, with no axe violations' do
    visit "/#{I18n.default_locale}/billing/orders/#{order.id}"

    within('#billing-order-refunds') do
      expect(page).to have_text('US$12.50')
      expect(page).to have_text('June 15, 2026')
      expect(page).to have_text('Recorded by the seller')
    end
    expect(page).to be_axe_clean.according_to(*wcag).within('main')
  end

  it 'shows what was given back on the billing page, with no axe violations' do
    visit "/#{I18n.default_locale}/billing"

    expect(page).to have_css("##{ActionView::RecordIdentifier.dom_id(order, :hub_refunded)}", text: 'US$12.50')
    expect(page).to be_axe_clean.according_to(*wcag).within('main')
  end
end
