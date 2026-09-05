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

  describe 'locatable_location_build overrides (build a new nested record)' do
    it 'Address builds a new record from attrs instead of looking one up' do
      result = BetterTogether::Address.locatable_location_build('line1' => '1 Main St')

      expect(result).to be_a(BetterTogether::Address)
      expect(result).not_to be_persisted
      expect(result.line1).to eq('1 Main St')
    end

    it 'Building still hoists top-level address attributes into address_attributes when built from another form' do
      result = BetterTogether::Infrastructure::Building.locatable_location_build('line1' => '1 Main St')

      expect(result).to be_a(BetterTogether::Infrastructure::Building)
      expect(result.address.line1).to eq('1 Main St')
    end
  end

  describe '.inline_creatable?' do
    it 'is false by default (lookup-only types)' do
      expect(BetterTogether::Geography::Settlement.inline_creatable?).to be(false)
      expect(BetterTogether::Geography::Region.inline_creatable?).to be(false)
    end

    it 'is false for Building even though it can build a new record from nested attrs' do
      # Buildings are curated reference data - selectable from the existing set but
      # never created inline from the event location form.
      expect(BetterTogether::Infrastructure::Building.inline_creatable?).to be(false)
    end

    it 'is true only for Address, the one type that renders inline-create fields in the picker' do
      expect(BetterTogether::Address.inline_creatable?).to be(true)
    end
  end

  describe '.inline_create_fields_partial' do
    it 'is nil by default and for Building' do
      expect(BetterTogether::Geography::Settlement.inline_create_fields_partial).to be_nil
      expect(BetterTogether::Infrastructure::Building.inline_create_fields_partial).to be_nil
    end

    it 'points at the Address inline-create fields partial' do
      expect(BetterTogether::Address.inline_create_fields_partial).to eq('better_together/addresses/address_fields')
    end
  end
end
