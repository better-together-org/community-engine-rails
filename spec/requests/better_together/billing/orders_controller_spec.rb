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

  it 'pages the list, newest first' do
    stub_const("#{described_class}::PER_PAGE", 2)
    newer = Array.new(2) { |i| travel_to((i + 1).minutes.from_now) { place_order } }
    sign_in member

    get orders_path
    first_page = ActionView::RecordIdentifier.dom_id(newer.last)
    expect(response.body).to include('billing-orders-pagination', first_page)
    expect(response.body).not_to include(ActionView::RecordIdentifier.dom_id(order))

    get orders_path, params: { page: 2 }
    expect(response.body).to include(ActionView::RecordIdentifier.dom_id(order))
    expect(response.body).not_to include(first_page)
  end

  describe 'filters' do
    let(:dom) { ActionView::RecordIdentifier }
    let!(:old_order) do
      place_order.tap { |o| o.update_columns(created_at: Time.utc(2025, 6, 1)) } # rubocop:disable Rails/SkipsModelValidations
    end

    before { sign_in member }

    it 'offers a status filter and the years the buyer has orders in' do
      get orders_path

      expect(response.body).to include('billing-orders-filters', 'billing-orders-filter-status', 'billing-orders-filter-year', '>2025<')
    end

    it 'keeps only the chosen year' do
      get orders_path, params: { year: 2025 }

      expect(response.body).to include(dom.dom_id(old_order))
      expect(response.body).not_to include(dom.dom_id(order))
    end

    it 'keeps only the chosen status' do
      old_order.update_columns(status: 'cancelled') # rubocop:disable Rails/SkipsModelValidations

      get orders_path, params: { status: 'cancelled' }

      expect(response.body).to include(dom.dom_id(old_order))
      expect(response.body).not_to include(dom.dom_id(order))
    end

    it 'says so when nothing matches, and offers to clear the filters' do
      get orders_path, params: { year: 2030 }

      expect(response.body).to include('billing-orders-empty', 'billing-orders-filter-clear')
    end

    it 'ignores a status or year it does not know' do
      get orders_path, params: { status: 'bogus', year: "2025'; drop" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(dom.dom_id(order), dom.dom_id(old_order))
    end
  end

  it 'is a 404 while billing is off for the platform' do
    sign_in member
    allow(BetterTogether::Billing::Configuration).to receive(:requested?).and_return(false)

    get orders_path

    expect(response).to have_http_status(:not_found)
  end

  context 'when signed in as the buyer' do
    before { sign_in member }

    describe 'the stored invoice and receipt' do
      let(:dom_id) { ActionView::RecordIdentifier }

      it 'shows no download button while no document has been made', :aggregate_failures do
        get order_path(order)

        expect(response.body).not_to include('billing-order-document-download')
      end

      it 'shows a download for the invoice, and the buyer can fetch the stored PDF', :aggregate_failures do
        document = BetterTogether::Billing::Orders::GenerateDocument.call(order)

        get order_path(order)

        expect(response.body).to include(dom_id.dom_id(order, :documents), dom_id.dom_id(document, :download), 'billing-order-invoice-download')
        expect(response.body).not_to include('billing-order-receipt-download')

        get better_together.download_file_path(document.upload, locale:)
        expect(response).to have_http_status(:ok)
        expect(response.body).to start_with('%PDF')
      end

      it 'does not give the file to anyone else', :aggregate_failures do
        document = BetterTogether::Billing::Orders::GenerateDocument.call(order)
        sign_in stranger

        get better_together.download_file_path(document.upload, locale:)

        expect(response).not_to have_http_status(:ok)
      end
    end

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

    it 'shows an order with its line items, status and payments' do
      BetterTogether::Billing::Payments::Create.call(order:, processor: 'fake', amount_cents: 4500, idempotency_key: 'k')

      get order_path(order)

      expect(response).to have_http_status(:ok)
      dom_id = ActionView::RecordIdentifier
      expect(response.body).to include(dom_id.dom_id(order, :details), dom_id.dom_id(order, :status_badge), 'billing-order-line-items',
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
