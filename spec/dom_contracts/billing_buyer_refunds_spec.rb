# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the refunds a buyer sees: the stable identifiers that documentation screenshots target.
RSpec.describe 'Billing buyer refunds DOM contract', type: :request do # rubocop:disable RSpec/DescribeClass
  include_context 'with offline payment fixtures'
  include_context 'with billing switched on'

  let(:locale) { I18n.default_locale }
  let(:order) { place_offline('cash') }
  let!(:refund) do
    transition.receive(offline_for(order), by: steward)
    BetterTogether::Billing::Refunds::Record.call(payment: offline_for(order).payment.reload, amount_cents: 1250, idempotency_key: 'one',
                                                  reason: 'requested_by_buyer', recorded_by: steward)
  end

  def expect_ids(*ids)
    ids.each { |id| expect(response.body).to include(%(id="#{id}")), "expected id=#{id.inspect} in the page" }
  end

  def dom_id(*) = ActionView::RecordIdentifier.dom_id(*)

  before { sign_in buyer_user }

  it 'exposes the refunds on the order: the card, its table, a row per refund and the total' do
    get "/#{locale}/billing/orders/#{order.id}"

    expect_ids('billing-order-refunds', 'billing-order-refunds-table', dom_id(refund), dom_id(order, :refunded))
  end

  it 'exposes the refunded amount beside the order on the billing page' do
    get "/#{locale}/billing"

    expect_ids(dom_id(order, :hub_refunded))
  end
end
