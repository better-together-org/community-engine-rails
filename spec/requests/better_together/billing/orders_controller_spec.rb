# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::OrdersController do
  include_context 'with orders fixtures'
  include_context 'with billing switched on'

  let(:locale) { :en }
  let(:password) { 'SecureTest123!@#' }
  let(:member) { find_or_create_test_user("orders-member-#{SecureRandom.hex(4)}@example.test", password) }
  let(:stranger) { find_or_create_test_user("orders-stranger-#{SecureRandom.hex(4)}@example.test", password) }
  let(:buyer) { member.person }
  let!(:order) { place_order }

  def orders_path = better_together.billing_orders_path(locale:)
  def order_path(record) = better_together.billing_order_path(record, locale:)

  it 'sends a visitor to sign in' do
    get orders_path

    expect(response).to have_http_status(:found)
  end

  it 'is a 404 while billing is off for the platform' do
    sign_in member
    allow(BetterTogether::Billing::Configuration).to receive(:requested?).and_return(false)

    get orders_path

    expect(response).to have_http_status(:not_found)
  end

  context 'when signed in as the buyer' do
    before { sign_in member }

    it 'lists their orders' do
      get orders_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('billing-orders-table', ActionView::RecordIdentifier.dom_id(order))
      expect_html_content(order.number)
    end

    it 'says so when there are none' do
      # An order with evidence on it cannot be deleted, so it is moved to someone else.
      BetterTogether::Billing::Order.connection.execute("UPDATE better_together_billing_orders SET buyer_id = '#{stranger.person.id}'")

      get orders_path

      expect(response.body).to include('billing-orders-empty')
    end

    it 'shows an order with its lines, status and payments' do
      BetterTogether::Billing::Payments::Create.call(order:, processor: 'fake', amount_cents: 4500, idempotency_key: 'k')

      get order_path(order)

      expect(response).to have_http_status(:ok)
      dom_id = ActionView::RecordIdentifier
      expect(response.body).to include(dom_id.dom_id(order, :details), dom_id.dom_id(order, :status_badge), 'billing-order-lines',
                                       'billing-order-payments', dom_id.dom_id(order, :total))
      expect_html_content(plan.name)
    end

    it 'lists the agreements accepted for the order, with who and when' do
      get order_path(order)

      expect(response.body).to include('billing-order-agreements', ActionView::RecordIdentifier.dom_id(order.agreement_acceptances.first))
      expect_html_content(order.agreement_acceptances.first.agreement_title)
    end

    it 'shows when there is no payment yet' do
      get order_path(order)

      expect(response.body).to include('billing-order-no-payments')
    end

    it 'does not show another buyer\'s order' do
      stranger_order = place_order(buyer: stranger.person)

      get order_path(stranger_order)

      expect(response).to have_http_status(:not_found)
    end

    it 'does not list another buyer\'s orders' do
      place_order(buyer: stranger.person)

      get orders_path

      expect(response.body.scan('billing-orders-table').size).to eq(1)
      expect(response.body.scan('id="billing_order_').size).to eq(1)
    end

    it 'does not show another platform\'s order, even one of the buyer\'s' do
      foreign = create(:better_together_billing_order, platform: create(:better_together_platform), buyer: member.person)

      get order_path(foreign)

      expect(response).to have_http_status(:not_found)
    end
  end

  context 'when signed in as someone else' do
    before { sign_in stranger }

    it 'cannot see the order' do
      get order_path(order)

      expect(response).to have_http_status(:not_found)
    end
  end
end
