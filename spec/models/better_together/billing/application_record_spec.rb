# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::ApplicationRecord do
  it 'is abstract and orders by creation time' do
    expect(described_class).to be_abstract_class
    expect(described_class.implicit_order_column).to eq(:created_at)
  end

  it 'cannot export a billing record into a seed, because it is not Seedable' do
    expect(described_class.ancestors).not_to include(BetterTogether::Seedable)
    expect(Pay::Customer.ancestors).not_to include(BetterTogether::Seedable)
    expect(Pay::Customer.new).not_to respond_to(:export_as_seed)
  end

  it 'is the base the billing models inherit, and the base of Pay through PayRecord' do
    expect(BetterTogether::Billing::PayRecord.superclass).to eq(described_class)
    expect(Pay::ApplicationRecord.superclass).to eq(BetterTogether::Billing::PayRecord)
  end
end
