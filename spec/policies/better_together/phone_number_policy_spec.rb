# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PhoneNumberPolicy, type: :policy do
  it 'inherits from ContactDetailPolicy' do
    expect(described_class.superclass).to eq(BetterTogether::ContactDetailPolicy)
  end

  describe 'write actions' do
    it 'deny a class-level or anonymous check, as there is no contactable owner', :aggregate_failures do
      expect(described_class.new(nil, nil).create?).to be false
      expect(described_class.new(nil, BetterTogether::PhoneNumber).destroy?).to be false
    end
  end

  describe 'Scope' do
    it 'inherits from ContactDetailPolicy::Scope' do
      expect(described_class::Scope.superclass).to eq(BetterTogether::ContactDetailPolicy::Scope)
    end
  end
end
