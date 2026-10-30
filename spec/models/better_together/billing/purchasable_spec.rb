# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Purchasable do
  it 'registers a model by name when it opts in' do
    expect(described_class.model_names).to include('BetterTogether::Billing::Plan')
    expect(described_class.model_names).not_to include('BetterTogether::Person')
  end

  describe 'a model that opts in without describing itself' do
    let(:model) { Class.new { include BetterTogether::Billing::Purchasable } }

    it 'must say what it is called, costs and is priced in' do
      expect { model.new.purchasable_description }.to raise_error(NotImplementedError)
      expect { model.new.purchasable_amount_cents }.to raise_error(NotImplementedError)
      expect { model.new.purchasable_currency }.to raise_error(NotImplementedError)
    end

    it 'holds nothing by default, and is for sale' do
      expect(model.new).to be_purchasable
      expect { model.new.reserve!(quantity: 2) }.not_to raise_error
      expect { model.new.release!(quantity: 2) }.not_to raise_error
    end
  end

  describe 'a plan' do
    include_context 'with orders fixtures'

    it 'describes itself for an order line, and is for sale only while active' do
      expect(plan).to have_attributes(purchasable_description: plan.name, purchasable_amount_cents: 4500, purchasable_currency: 'USD')
      expect(plan).to be_purchasable
      plan.update!(active: false)
      expect(plan).not_to be_purchasable
    end
  end
end
