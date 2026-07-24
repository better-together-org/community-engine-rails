# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Geography::Placeable do
  describe '.included_in_models' do
    it 'returns exactly the models that include this concern' do
      models = described_class.included_in_models

      expect(models).to include(
        BetterTogether::Address,
        BetterTogether::Infrastructure::Building,
        BetterTogether::Geography::Settlement,
        BetterTogether::Geography::Region
      )
      expect(models).not_to include(BetterTogether::Event)
    end
  end

  describe '.locatable_location_build (default, lookup-only)' do
    it 'finds an existing Settlement by id and never builds a new record' do
      settlement = create(:geography_settlement)

      result = BetterTogether::Geography::Settlement.locatable_location_build('location_id' => settlement.id)

      expect(result).to eq(settlement)
    end

    it 'finds an existing Region by the id key too' do
      region = create(:geography_region)

      result = BetterTogether::Geography::Region.locatable_location_build('id' => region.id)

      expect(result).to eq(region)
    end

    it 'returns nil when no matching record exists' do
      result = BetterTogether::Geography::Settlement.locatable_location_build('location_id' => SecureRandom.uuid)

      expect(result).to be_nil
    end
  end

  describe 'Address/Building overrides (build a new nested record)' do
    it 'Address builds a new record from attrs instead of looking one up' do
      result = BetterTogether::Address.locatable_location_build('line1' => '1 Main St')

      expect(result).to be_a(BetterTogether::Address)
      expect(result).not_to be_persisted
      expect(result.line1).to eq('1 Main St')
    end

    it 'Building hoists top-level address attributes into address_attributes' do
      result = BetterTogether::Infrastructure::Building.locatable_location_build('line1' => '1 Main St')

      expect(result).to be_a(BetterTogether::Infrastructure::Building)
      expect(result.address.line1).to eq('1 Main St')
    end
  end
end
