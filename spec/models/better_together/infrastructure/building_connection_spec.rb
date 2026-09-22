# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Infrastructure::BuildingConnection do
  subject(:connection) do
    described_class.new(building: building, connection: community)
  end

  let(:building) { create(:better_together_infrastructure_building) }
  let(:community) { create(:better_together_community) }

  describe 'associations' do
    it 'belongs to a building' do
      connection.save!
      expect(connection.building).to be_a(BetterTogether::Infrastructure::Building)
    end

    it 'belongs to a polymorphic connection' do
      connection.save!
      expect(connection.connection).to eq(community)
    end
  end

  describe 'delegates' do
    it 'delegates name to building' do
      expect(connection).to respond_to(:name)
    end

    it 'delegates address to building' do
      expect(connection).to respond_to(:address)
    end
  end

  describe '.permitted_attributes' do
    it 'includes connection_id' do
      expect(described_class.permitted_attributes).to include(:connection_id)
    end

    it 'includes building_attributes' do
      attrs = described_class.permitted_attributes
      building_attrs = attrs.find { |a| a.is_a?(Hash) && a.key?(:building_attributes) }
      expect(building_attrs).to be_present
    end
  end

  describe '#building' do
    it 'builds a new building if none is assigned' do
      bc = described_class.new(connection: community)
      expect(bc.building).to be_a(BetterTogether::Infrastructure::Building)
    end
  end
end
