# frozen_string_literal: true

require 'rails_helper'

# DOM contract for paying an order through a processor: the identifiers that documentation screenshots and
# downstream tooling target. Runs in normal CI.
RSpec.describe 'Billing order pay DOM contract', type: :request do # rubocop:disable RSpec/DescribeClass
  include_context 'with orders fixtures'
  include_context 'with billing switched on'

  let(:password) { 'SecureTest123!@#' }
  let(:member) { find_or_create_test_user("pay-dom-#{SecureRandom.hex(4)}@example.test", password) }
  let(:buyer) { member.person }
  let!(:order) { place_order(payment_method: 'fake') }

  before { sign_in member }

  def expect_ids(*ids)
    ids.each { |id| expect(response.body).to include(%(id="#{id}")), "expected id=#{id.inspect} in the page" }
  end

  it 'exposes the card, the hint and the button for a payment to make' do
    get "/#{I18n.default_locale}/billing/orders/#{order.id}"

    expect_ids('billing-order-pay-card', 'billing-order-pay-hint', 'billing-order-pay-btn')
  end

  it 'exposes the card and the hint, but no button, while the processor has the payment in flight' do
    order.payments.first.update!(status: 'processing')

    get "/#{I18n.default_locale}/billing/orders/#{order.id}"

    expect_ids('billing-order-pay-card', 'billing-order-pay-hint')
    expect(response.body).not_to include('id="billing-order-pay-btn"')
  end
end
