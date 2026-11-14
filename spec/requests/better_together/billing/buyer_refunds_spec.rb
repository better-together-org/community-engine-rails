# frozen_string_literal: true

require 'rails_helper'

# A buyer sees the money given back against their own orders: how much, when, and where it stands. Only their own.
RSpec.describe 'Billing refunds seen by the buyer' do # rubocop:disable RSpec/DescribeClass
  include_context 'with offline payment fixtures'
  include_context 'with billing switched on'

  let(:locale) { I18n.default_locale }
  let(:order) { place_offline('cash') }
  let(:offline) { offline_for(order) }
  let(:payment) { offline.payment }
  let(:page) { Nokogiri::HTML(response.body) }

  def refund!(cents, key: SecureRandom.hex(4), **attrs)
    BetterTogether::Billing::Refunds::Record.call(payment: payment.reload, amount_cents: cents, idempotency_key: key,
                                                  reason: 'requested_by_buyer', recorded_by: steward, **attrs)
  end

  before { transition.receive(offline, by: steward) }

  describe 'the order page' do
    before { sign_in buyer_user }

    it 'lists no refunds section while nothing was given back' do
      get "/#{locale}/billing/orders/#{order.id}"

      expect(response).to have_http_status(:ok)
      expect(page.at_css('#billing-order-refunds')).to be_nil
    end

    it 'shows each refund with its amount, date and status, and the total given back' do
      refund = refund!(1250)
      refund.update_columns(created_at: Time.utc(2026, 6, 15, 16)) # rubocop:disable Rails/SkipsModelValidations

      get "/#{locale}/billing/orders/#{order.id}"

      row = page.at_css("##{ActionView::RecordIdentifier.dom_id(refund)}")
      expect(row.text).to include('US$12.50', 'June 15, 2026', 'Recorded by the seller')
      expect(page.at_css("##{ActionView::RecordIdentifier.dom_id(order, :refunded)}").text).to include('US$12.50')
    end

    it 'keeps the reason a steward recorded to the steward' do
      refund!(1250, reason: 'fraudulent')

      get "/#{locale}/billing/orders/#{order.id}"

      expect(response.body).not_to match(/fraudulent/i)
    end

    it 'does not show a refund that failed' do
      failed = refund!(500)
      failed.update_columns(status: 'failed') # rubocop:disable Rails/SkipsModelValidations

      get "/#{locale}/billing/orders/#{order.id}"

      expect(page.at_css('#billing-order-refunds')).to be_nil
    end

    it 'is not reachable for another buyer\'s order' do
      refund!(1250)
      sign_in other_buyer_user

      get "/#{locale}/billing/orders/#{order.id}"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'the billing hub' do
    it 'shows what was given back beside the order, for the buyer who owns it' do
      refund!(1250)
      refund!(500)
      sign_in buyer_user

      get "/#{locale}/billing"

      expect(page.at_css("##{ActionView::RecordIdentifier.dom_id(order, :hub_refunded)}").text).to include('US$17.50')
    end

    it 'shows nothing of it to another buyer' do
      refund!(1250)
      sign_in other_buyer_user

      get "/#{locale}/billing"

      expect(response.body).not_to include(order.number)
      expect(response.body).not_to include('US$12.50')
    end

    it 'leaves orders with nothing given back as they were' do
      sign_in buyer_user

      get "/#{locale}/billing"

      expect(page.at_css("##{ActionView::RecordIdentifier.dom_id(order, :hub_refunded)}")).to be_nil
    end
  end
end
