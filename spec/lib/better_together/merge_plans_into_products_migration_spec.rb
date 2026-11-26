# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Merge plans into products migration' do # rubocop:disable RSpec/DescribeClass
  let(:connection) { ActiveRecord::Base.connection }

  it 'leaves no plans table, and plans live in products' do
    expect(connection.table_exists?(:better_together_billing_plans)).to be(false)
    expect(connection.columns(:better_together_billing_products).map(&:name))
      .to include('grace_days', 'renewal_lead_days', 'manages_processor_product', 'accepted_payment_methods')
  end

  it 'points terms at a price and entitlements and grants at a product' do
    expect(connection.columns(:better_together_billing_subscription_terms).map(&:name)).to include('price_id')
    expect(connection.columns(:better_together_billing_entitlements).map(&:name)).to include('product_id')
    expect(connection.columns(:better_together_billing_grants).map(&:name)).to include('product_id')
  end
end
