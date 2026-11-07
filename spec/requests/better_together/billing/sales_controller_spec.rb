# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::SalesController do
  include_context 'with orders fixtures'
  include_context 'with billing switched on'

  let(:locale) { :en }
  let(:password) { 'SecureTest123!@#' }
  let(:steward) { find_or_create_test_user("sales-steward-#{SecureRandom.hex(4)}@example.test", password, :platform_manager) }
  let(:member) { find_or_create_test_user("sales-member-#{SecureRandom.hex(4)}@example.test", password) }
  let(:other_platform) { create(:better_together_platform) }
  let!(:order) { place_order }

  def sales_path = better_together.billing_sales_path(locale:)
  def sale_path(record) = better_together.billing_sale_path(record, locale:)

  it 'sends a visitor to sign in' do
    get sales_path

    expect(response).to have_http_status(:found)
  end

  it 'turns a signed-in non-steward away' do
    sign_in member

    get sales_path

    expect(response).to have_http_status(:found)
    expect(response.body).not_to include('billing-sales-table')
  end

  it 'is a 404 while billing is off' do
    sign_in steward
    allow(BetterTogether::Billing::Configuration).to receive(:requested?).and_return(false)

    get sales_path

    expect(response).to have_http_status(:not_found)
  end

  context 'when signed in as a steward' do
    before { sign_in steward }

    it 'lists what the platform sells, with the buyer' do
      get sales_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('billing-sales-table', ActionView::RecordIdentifier.dom_id(order))
      expect_html_contents(order.number, buyer.name)
    end

    it 'says so when nothing was sold' do
      order.destroy!

      get sales_path

      expect(response.body).to include('billing-sales-empty')
    end

    it 'shows one sale with who placed it, its lines and payments' do
      BetterTogether::Billing::Payments::Create.call(order:, processor: 'fake', amount_cents: 4500, idempotency_key: 'k')

      get sale_path(order)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(ActionView::RecordIdentifier.dom_id(order, :buyer), 'billing-order-lines', 'billing-order-payments')
      expect_html_content(buyer.name)
    end

    it 'does not list or show another platform\'s orders' do
      foreign = create(:better_together_billing_order, platform: other_platform)

      get sales_path
      expect(response.body).not_to include(foreign.number)

      get sale_path(foreign)
      expect(response).to have_http_status(:not_found)
    end

    it 'does not list or show an order a community sold' do
      BetterTogether::Billing::Billable.model_names << 'BetterTogether::Community'
      sold = create(:better_together_billing_order, seller: create(:better_together_community))

      get sales_path
      expect(response.body).not_to include(sold.number)

      get sale_path(sold)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'many sales' do
    let(:sales_query_count) do
      lambda do
        count = 0
        counter = lambda do |*, payload|
          count += 1 unless %w[SCHEMA TRANSACTION].include?(payload[:name]) || payload[:sql].match?(/\A(BEGIN|COMMIT|SAVEPOINT|RELEASE)/)
        end
        ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') { get sales_path }
        count
      end
    end

    it 'does not run more queries per extra sale' do
      sign_in steward
      sales_query_count.call # warm up
      before_count = sales_query_count.call
      4.times { place_order(buyer: create(:better_together_person)) }

      expect(sales_query_count.call).to be <= before_count + 1
    end

    it 'shows one page at a time' do
      sign_in steward
      stub_const('BetterTogether::Billing::SalesController::PER_PAGE', 1)
      place_order(buyer: create(:better_together_person))

      get sales_path

      expect(response.body.scan('id="billing-sales-table"').size).to eq(1)
      expect(response.parsed_body.css('#billing-sales-table tbody tr').size).to eq(1)
      expect(response.body).to include('billing-sales-pagination')
    end
  end
end
