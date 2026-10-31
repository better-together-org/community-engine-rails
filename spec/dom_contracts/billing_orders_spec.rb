# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the order screens: asserts the stable identifiers that documentation
# screenshots (spec/docs_screenshots/better_together/billing_orders_spec.rb) and downstream
# tooling target. Runs in normal CI (no RUN_DOCS_SCREENSHOTS gate).
RSpec.describe 'Billing orders DOM contract', :as_platform_manager, type: :request do # rubocop:disable RSpec/DescribeClass
  include_context 'with orders fixtures'
  include_context 'with billing switched on'

  let(:locale) { I18n.default_locale }
  let(:buyer) { BetterTogether::User.find_by!(email: 'manager@example.test').person }
  let!(:order) { place_order }
  let(:dom_id) { ActionView::RecordIdentifier }

  def expect_ids(*ids)
    ids.each { |id| expect(response.body).to include(%(id="#{id}")), "expected id=#{id.inspect} in the page" }
  end

  before do
    BetterTogether::Billing::Payments::Create.call(order:, processor: 'fake', amount_cents: 1500, idempotency_key: 'one')
  end

  it 'exposes the buyer\'s list' do
    get "/#{locale}/billing/orders"

    expect_ids('billing-orders-page', 'billing-orders-table', dom_id.dom_id(order))
    expect(response.body).to include('billing-order-status-badge')
  end

  it 'exposes the buyer\'s empty list' do
    # An order with evidence on it cannot be deleted, so it is moved to someone else.
    someone_else = create(:better_together_person)
    BetterTogether::Billing::Order.connection.execute("UPDATE better_together_billing_orders SET buyer_id = '#{someone_else.id}'")

    get "/#{locale}/billing/orders"

    expect_ids('billing-orders-empty')
  end

  it 'exposes an order: details, status, totals, lines and payments' do
    get "/#{locale}/billing/orders/#{order.id}"

    expect(response).to have_http_status(:ok)
    expect_ids(dom_id.dom_id(order, :show_page), dom_id.dom_id(order, :details), dom_id.dom_id(order, :status_badge),
               dom_id.dom_id(order, :placed_at), dom_id.dom_id(order, :purpose), dom_id.dom_id(order, :total), dom_id.dom_id(order, :paid),
               dom_id.dom_id(order, :expires_at), 'billing-order-lines', dom_id.dom_id(order.lines.first),
               'billing-order-payments', dom_id.dom_id(order.payments.first))
  end

  it 'exposes the steward\'s list of sales' do
    get "/#{locale}/billing/sales"

    expect_ids('billing-sales-page', 'billing-sales-table', dom_id.dom_id(order))
  end

  it 'exposes a sale with who placed it' do
    get "/#{locale}/billing/sales/#{order.id}"

    expect_ids(dom_id.dom_id(order, :show_page), dom_id.dom_id(order, :buyer), dom_id.dom_id(order, :details), 'billing-order-lines')
  end
end
