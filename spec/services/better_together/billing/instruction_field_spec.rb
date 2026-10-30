# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::InstructionField do
  it 'normalises its name and type to symbols and defaults to an optional string' do
    field = described_class.new(name: 'payee_email', type: 'email', required: true)

    expect(field).to have_attributes(name: :payee_email, type: :email, required: true)
    expect(field).to be_required
    expect(described_class.new(name: :note)).to have_attributes(type: :string, required: false)
  end

  it 'refuses a type it cannot render and store' do
    expect { described_class.new(name: :x, type: :iban) }.to raise_error(ArgumentError, /unknown instruction field type/)
  end

  it 'does not leak its type list into the Billing namespace' do
    expect(BetterTogether::Billing.const_defined?(:TYPES, false)).to be(false)
  end
end
