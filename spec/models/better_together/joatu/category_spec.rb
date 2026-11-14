# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Joatu::Category do
  it 'inherits from BetterTogether::Category' do
    expect(described_class.superclass).to eq(BetterTogether::Category)
  end

  it 'responds to offers' do
    expect(described_class.new).to respond_to(:offers)
  end

  it 'responds to requests' do
    expect(described_class.new).to respond_to(:requests)
  end

  describe 'creation' do
    it 'can be created with a name' do
      category = create(:better_together_joatu_category)
      expect(category).to be_persisted
      expect(category.name).to be_present
    end
  end
end
