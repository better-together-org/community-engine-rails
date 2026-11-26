# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Price, '#payment_methods online' do
  include_context 'with orders fixtures'

  let(:product) { create(:better_together_billing_product, platform: host_platform, processor: nil) }
  let(:price) { create(:better_together_billing_price, product:, amount_cents: 800, currency: 'USD') }

  it 'offers an online processor only when the product names it' do
    expect(price.payment_methods).not_to include('fake')

    product.update_columns(processor: 'fake') # rubocop:disable Rails/SkipsModelValidations
    expect(price.reload.payment_methods).to include('fake')
  end
end
