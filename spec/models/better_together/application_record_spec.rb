# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ApplicationRecord do
  it 'is an abstract class' do
    expect(described_class.abstract_class).to be true
  end

  describe '.permitted_attributes' do
    it 'returns empty array by default' do
      expect(described_class.permitted_attributes).to eq([])
    end

    it 'includes :id when id: true' do
      expect(described_class.permitted_attributes(id: true)).to include(:id)
    end

    it 'includes :_destroy when destroy: true' do
      expect(described_class.permitted_attributes(destroy: true)).to include(:_destroy)
    end
  end

  describe '.extra_permitted_attributes' do
    it 'returns an empty array on the base class' do
      expect(described_class.extra_permitted_attributes).to eq([])
    end
  end
end
