# frozen_string_literal: true

require 'rails_helper'

# A steward returns the parts of a part-paid order and cancels it.
RSpec.describe 'Returning payments and cancelling a sale' do # rubocop:disable RSpec/DescribeClass
  include_context 'with subscription fixtures'
  include_context 'with billing switched on'

  let(:locale) { :en }
  let(:order) do
    give_credit(1000)
    place_order(payments: [{ payment_method: 'store_credit', amount_cents: 1000 }, { payment_method: 'cash', amount_cents: 1500 }],
                payment_method: nil)
  end

  def sale_path(record = order) = better_together.billing_sale_path(record, locale:)
  def return_path(record = order) = better_together.return_payments_billing_sale_path(record, locale:)
  def cancel_path(record = order) = better_together.cancel_billing_sale_path(record, locale:)

  it 'turns a visitor and the buyer away' do
    post cancel_path
    expect(response).to have_http_status(:found)

    sign_in buyer_user
    post return_path
    post cancel_path

    expect(order.reload).to be_partially_paid
  end

  context 'when signed in as a steward' do
    before { sign_in steward_user }

    it 'shows what is left to return, and how, and no cancel button while money is against the order' do
      get sale_path

      expect(response.body).to include(ActionView::RecordIdentifier.dom_id(order, :return_payments), 'billing-sale-return-credit-btn')
      expect(response.body).not_to include('billing-sale-cancel-btn')
    end

    it 'returns the credit, then offers and performs the cancel' do
      post return_path
      expect(response).to redirect_to(sale_path)
      expect(order.reload).to be_awaiting_payment

      get sale_path
      expect(response.body).to include('billing-sale-cancel-btn')
      expect(response.body).not_to include('billing-sale-return-credit-btn')

      post cancel_path
      expect(response).to redirect_to(sale_path)
      expect(order.reload).to be_cancelled
    end

    it 'refuses to cancel while money is still against the order' do
      post cancel_path

      expect(flash[:alert]).to be_present
      expect(order.reload).to be_partially_paid
    end

    it 'does not reach an order of another platform or one sold by a seller' do
      other = create(:better_together_platform)
      sold = create(:better_together_billing_order, platform: other)

      post cancel_path(sold)

      expect(response).to have_http_status(:not_found)
    end
  end
end
