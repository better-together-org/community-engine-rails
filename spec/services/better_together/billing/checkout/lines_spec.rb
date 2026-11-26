# frozen_string_literal: true

require 'rails_helper'

# PS-7: core works out the lines and mode of a processor checkout session from the order, so an adapter does not.
RSpec.describe BetterTogether::Billing::Checkout::Lines do
  include_context 'with orders fixtures'

  let(:product) { create(:better_together_billing_product, platform: host_platform, name: 'Top-up', processor: nil) }
  let(:price) { create(:better_together_billing_price, product:, amount_cents: 800, currency: 'USD') }
  let(:orders) { BetterTogether::Billing::Order }

  def lines_for(*purchasables, **options)
    order = place_order(payment_method: 'fake', line_items: purchasables.map { |item| { purchasable: item, **options } })
    described_class.call(order:, processor: 'fake')
  end

  it 'is a subscription when a plan recurs, naming the plan price the processor holds' do
    result = lines_for(plan)

    expect(result.mode).to eq(:subscription)
    expect(result.lines.sole).to have_attributes(processor_price_id: plan.processor_price_id, price_data: nil, recurring?: true)
  end

  it 'is a payment when every line is one-time, and sends a product price inline when the processor does not hold it' do
    result = lines_for(price, quantity: 2)

    expect(result.mode).to eq(:payment)
    line = result.lines.sole
    expect(line).to have_attributes(quantity: 2, processor_price_id: nil, recurring?: false)
    expect(line.price_data).to have_attributes(amount_cents: 800, currency: 'USD', interval: 'one_time', name: 'Top-up')
  end

  it 'names the processor price when the product is held by this processor and the price is on it' do
    product.update_columns(processor: 'fake') # rubocop:disable Rails/SkipsModelValidations
    price.update_columns(processor_price_id: 'price_held') # rubocop:disable Rails/SkipsModelValidations

    expect(lines_for(price).lines.sole).to have_attributes(processor_price_id: 'price_held', price_data: nil)
  end

  it 'still sends it inline when the product is held by another processor' do
    product.update_columns(processor: 'other') # rubocop:disable Rails/SkipsModelValidations
    price.update_columns(processor_price_id: 'price_held') # rubocop:disable Rails/SkipsModelValidations

    expect(lines_for(price).lines.sole).to have_attributes(processor_price_id: nil).and have_attributes(inline?: true)
  end

  it 'refuses a plan that is not linked to the processor' do
    order = place_order(payment_method: 'fake', line_items: [{ purchasable: plan }])
    plan.update_columns(processor_price_id: nil) # rubocop:disable Rails/SkipsModelValidations

    expect { described_class.call(order:, processor: 'fake') }.to raise_error(described_class::Unmirrored)
  end

  it 'refuses a line that has both a processor price and inline data' do
    data = BetterTogether::Billing::InlinePrice.new(amount_cents: 1, currency: 'USD', interval: 'one_time', interval_count: 1, name: 'x',
                                                    description: nil)

    expect do
      BetterTogether::Billing::CheckoutLine.new(ref: 'l', quantity: 1, processor_price_id: 'p', price_data: data)
    end.to raise_error(ArgumentError)
    expect { BetterTogether::Billing::CheckoutLine.new(ref: 'l', quantity: 1) }.to raise_error(ArgumentError)
  end
end
