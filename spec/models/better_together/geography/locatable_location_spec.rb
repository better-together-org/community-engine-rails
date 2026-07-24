# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Geography::LocatableLocation do
  subject(:locatable_location) { build(:locatable_location) }

  describe 'associations' do
    it { is_expected.to belong_to(:locatable) }
    it { is_expected.to belong_to(:location).optional }
  end

  describe 'validations' do
    context 'when simple location' do
      subject(:simple_location) { build(:locatable_location, :simple) }

      it { is_expected.to validate_presence_of(:name) }
      it { is_expected.to be_valid }
    end

    context 'when structured location' do
      subject(:structured_location) { build(:locatable_location, :with_address) }

      it { is_expected.to be_valid }

      it 'does not require name for structured locations' do
        structured_location.name = nil
        expect(structured_location).to be_valid
      end
    end

    context 'when neither name nor location provided' do
      subject(:invalid_location) { build(:locatable_location) }

      before do
        invalid_location.name = nil
        invalid_location.location = nil
      end

      it { is_expected.not_to be_valid }

      it 'adds validation error' do
        invalid_location.valid?
        expect(invalid_location.errors[:base]).to include(
          I18n.t('better_together.geography.locatable_location.errors.no_location_source',
                 default: 'Must specify either a name or location')
        )
      end
    end
  end

  describe 'instance methods' do
    describe '#to_s' do
      it 'returns display_name' do
        expect(locatable_location.to_s).to eq(locatable_location.display_name)
      end
    end

    describe '#display_name' do
      context 'when name is present' do
        let(:location_with_name) { build(:locatable_location, name: 'Test Location') }

        it 'returns the name' do
          expect(location_with_name.display_name).to eq('Test Location')
        end
      end

      context 'when location is present but name is not' do
        let(:structured_location) { build(:locatable_location, :with_address, name: nil) }

        it 'returns location.to_s' do
          allow(structured_location.location).to receive(:to_s).and_return('123 Main St')
          expect(structured_location.display_name).to eq('123 Main St')
        end
      end

      context 'when neither name nor location are present' do
        let(:empty_location) do
          location = build(:locatable_location)
          location.name = nil
          location.location = nil
          location
        end

        it 'returns default text' do
          expect(empty_location.display_name).to eq('Unnamed Location')
        end
      end
    end

    describe '#geocoding_string' do
      context 'when location responds to geocoding_string' do
        let(:structured_location) { build(:locatable_location, :with_address) }

        it 'delegates to location' do
          allow(structured_location.location).to receive(:geocoding_string).and_return('123 Main St, City')
          expect(structured_location.geocoding_string).to eq('123 Main St, City')
        end
      end

      context 'when location does not respond to geocoding_string' do
        let(:simple_location) { build(:locatable_location, :simple, name: 'Simple Location') }

        it 'returns name as fallback' do
          expect(simple_location.geocoding_string).to eq('Simple Location')
        end
      end
    end

    describe '#simple_location?' do
      context 'when location is blank' do
        let(:simple_location) { build(:locatable_location, :simple) }

        it 'returns true' do
          expect(simple_location.simple_location?).to be true
        end
      end

      context 'when location is present' do
        let(:structured_location) { build(:locatable_location, :with_address) }

        it 'returns false' do
          expect(structured_location.simple_location?).to be false
        end
      end
    end

    describe '#structured_location?' do
      it 'returns opposite of simple_location?' do
        simple_location = build(:locatable_location, :simple)
        structured_location = build(:locatable_location, :with_address)

        expect(simple_location.structured_location?).to be false
        expect(structured_location.structured_location?).to be true
      end
    end

    describe '#address' do
      context 'when location_type is Address' do
        let(:address_location) { build(:locatable_location, :with_address) }

        it 'returns the location' do
          expect(address_location.address).to eq(address_location.location)
        end
      end

      context 'when location_type is not Address' do
        let(:building_location) { build(:locatable_location, :with_building) }

        it 'returns nil' do
          expect(building_location.address).to be_nil
        end
      end
    end

    describe '#building' do
      context 'when location_type is Building' do
        let(:building_location) { build(:locatable_location, :with_building) }

        it 'returns the location' do
          expect(building_location.building).to eq(building_location.location)
        end
      end

      context 'when location_type is not Building' do
        let(:address_location) { build(:locatable_location, :with_address) }

        it 'returns nil' do
          expect(address_location.building).to be_nil
        end
      end
    end

    describe '#address?' do
      it 'returns true for address locations' do
        address_location = build(:locatable_location, :with_address)
        expect(address_location.address?).to be true
      end

      it 'returns false for non-address locations' do
        building_location = build(:locatable_location, :with_building)
        simple_location = build(:locatable_location, :simple)

        expect(building_location.address?).to be false
        expect(simple_location.address?).to be false
      end
    end

    describe '#building?' do
      it 'returns true for building locations' do
        building_location = build(:locatable_location, :with_building)
        expect(building_location.building?).to be true
      end

      it 'returns false for non-building locations' do
        address_location = build(:locatable_location, :with_address)
        simple_location = build(:locatable_location, :simple)

        expect(address_location.building?).to be false
        expect(simple_location.building?).to be false
      end
    end

    describe '#settlement' do
      it 'returns the location when location_type is Settlement' do
        settlement_location = build(:locatable_location, :with_settlement)
        expect(settlement_location.settlement).to eq(settlement_location.location)
      end

      it 'returns nil when location_type is not Settlement' do
        address_location = build(:locatable_location, :with_address)
        expect(address_location.settlement).to be_nil
      end
    end

    describe '#region' do
      it 'returns the location when location_type is Region' do
        region_location = build(:locatable_location, :with_region)
        expect(region_location.region).to eq(region_location.location)
      end

      it 'returns nil when location_type is not Region' do
        address_location = build(:locatable_location, :with_address)
        expect(address_location.region).to be_nil
      end
    end

    describe '#settlement?/#region?' do
      it 'returns true only for the matching type' do
        settlement_location = build(:locatable_location, :with_settlement)
        region_location = build(:locatable_location, :with_region)

        expect(settlement_location.settlement?).to be true
        expect(settlement_location.region?).to be false
        expect(region_location.region?).to be true
        expect(region_location.settlement?).to be false
      end
    end
  end

  describe 'settlement/region as structured locations' do
    context 'when settlement location' do
      subject(:settlement_location) { build(:locatable_location, :with_settlement) }

      it { is_expected.to be_valid }

      it 'does not require name' do
        settlement_location.name = nil
        expect(settlement_location).to be_valid
      end
    end

    context 'when region location' do
      subject(:region_location) { build(:locatable_location, :with_region) }

      it { is_expected.to be_valid }

      it 'does not require name' do
        region_location.name = nil
        expect(region_location).to be_valid
      end
    end
  end

  describe '#location_attributes=' do
    it 'assigns an existing Settlement (lookup-only, never builds a new one)' do
      settlement = create(:geography_settlement)
      locatable_location.location_attributes = { location_type: 'BetterTogether::Geography::Settlement',
                                                 location_id: settlement.id }

      expect(locatable_location.location).to eq(settlement)
    end

    it 'assigns an existing Region (lookup-only)' do
      region = create(:geography_region)
      locatable_location.location_attributes = { location_type: 'BetterTogether::Geography::Region',
                                                 location_id: region.id }

      expect(locatable_location.location).to eq(region)
    end

    it 'falls back to the simple name when location_type is not a Placeable model' do
      locatable_location.location_attributes = { location_type: 'BetterTogether::Person', name: 'Somewhere' }

      expect(locatable_location.location).to be_nil
      expect(locatable_location.name).to eq('Somewhere')
    end

    it 'builds a new Address when location_type is Address' do
      locatable_location.location_attributes = { location_type: 'BetterTogether::Address', line1: '1 Main St' }

      expect(locatable_location.location).to be_a(BetterTogether::Address)
      expect(locatable_location.location.line1).to eq('1 Main St')
    end

    it 'looks up an existing record by id across allowed types when only id is given' do
      settlement = create(:geography_settlement)
      locatable_location.location_attributes = { id: settlement.id }

      expect(locatable_location.location).to eq(settlement)
    end
  end

  describe 'class methods' do
    describe '.available_addresses_for' do
      let(:user) { create(:better_together_user, :confirmed) }
      let(:person) { user.person }
      let(:community) { create(:better_together_community) }
      let!(:public_address) { create(:better_together_address, privacy: 'public') }
      let!(:private_address) { create(:better_together_address, privacy: 'private') }

      context 'when context is nil' do
        it 'returns empty scope' do
          expect(described_class.available_addresses_for(nil)).to eq(BetterTogether::Address.none)
        end
      end

      context 'when context is a Person with user' do
        let!(:person_contact_detail) do
          create(:better_together_contact_detail, contactable: person)
        end

        let!(:person_address) do
          create(:better_together_address, privacy: 'private', contact_detail: person_contact_detail)
        end

        it 'uses policy scope to return authorized addresses' do
          result = described_class.available_addresses_for(person)

          # Should include public addresses at minimum
          expect(result).to include(public_address)
        end

        it 'includes proper associations' do
          result = described_class.available_addresses_for(person)

          expect(result.includes_values).to include(:contact_detail)
        end
      end

      context 'when context is a Person without user' do
        let(:person_without_user) { create(:better_together_person) }

        it 'returns only public addresses' do
          result = described_class.available_addresses_for(person_without_user)

          expect(result).to include(public_address)
          expect(result).not_to include(private_address)
        end
      end

      context 'when context is a Community' do
        let!(:community_contact_detail) do
          create(:better_together_contact_detail, contactable: community)
        end

        let!(:community_address) do
          create(:better_together_address, privacy: 'private', contact_detail: community_contact_detail)
        end

        it 'returns community addresses and public addresses' do
          result = described_class.available_addresses_for(community)

          expect(result).to include(community_address)
          expect(result).to include(public_address)
          expect(result).not_to include(private_address)
        end
      end

      context 'when context is unsupported type' do
        it 'returns only public addresses' do
          result = described_class.available_addresses_for('unsupported')

          expect(result).to include(public_address)
          expect(result).not_to include(private_address)
        end
      end
    end

    describe '.available_buildings_for' do
      let(:user) { create(:better_together_user, :confirmed) }
      let(:person) { user.person }
      let(:community) { create(:better_together_community) }
      let!(:public_building) { create(:better_together_infrastructure_building, privacy: 'public') }
      let!(:private_building) { create(:better_together_infrastructure_building, privacy: 'private') }

      context 'when context is nil' do
        it 'returns empty scope' do
          expect(described_class.available_buildings_for(nil)).to eq(BetterTogether::Infrastructure::Building.none)
        end
      end

      context 'when context is a Person with user' do
        let!(:person_building) do
          create(:better_together_infrastructure_building,
                 creator: person,
                 privacy: 'private')
        end

        it 'uses policy scope to return authorized buildings' do
          result = described_class.available_buildings_for(person)

          # Should include public buildings and person's own buildings
          expect(result).to include(public_building)
          expect(result).to include(person_building)
          expect(result).not_to include(private_building)
        end

        it 'includes proper associations' do
          result = described_class.available_buildings_for(person)

          expect(result.includes_values).to include(:string_translations)
          expect(result.includes_values).to include(:address)
        end
      end

      context 'when context is a Person without user' do
        let(:person_without_user) { create(:better_together_person) }

        it 'returns only public buildings' do
          result = described_class.available_buildings_for(person_without_user)

          expect(result).to include(public_building)
          expect(result).not_to include(private_building)
        end
      end

      context 'when context is a Community' do
        it 'returns only public buildings' do
          result = described_class.available_buildings_for(community)

          expect(result).to include(public_building)
          expect(result).not_to include(private_building)
        end
      end

      context 'when context is unsupported type' do
        it 'returns empty scope' do
          result = described_class.available_buildings_for('unsupported')

          expect(result).to eq(BetterTogether::Infrastructure::Building.none)
        end
      end
    end

    describe '.available_settlements_for' do
      let!(:settlement_a) { create(:geography_settlement, name: 'Zeta Settlement') }
      let!(:settlement_b) { create(:geography_settlement, name: 'Alpha Settlement') }

      it 'returns all settlements ordered by name, ignoring context' do
        result = described_class.available_settlements_for(nil)

        expect(result.to_a).to eq([settlement_b, settlement_a])
      end
    end

    describe '.available_regions_for' do
      let!(:region_a) { create(:geography_region, name: 'Zeta Region') }
      let!(:region_b) { create(:geography_region, name: 'Alpha Region') }

      it 'returns all regions ordered by name, ignoring context' do
        result = described_class.available_regions_for(nil)

        expect(result.to_a).to eq([region_b, region_a])
      end
    end

    describe '.permitted_attributes' do
      it 'includes location-specific attributes' do
        expected_attrs = %i[name locatable_id locatable_type location_id location_type]
        expect(described_class.permitted_attributes).to include(*expected_attrs)
      end

      it 'merges nested attributes dynamically across every Placeable model' do
        nested = described_class.permitted_attributes.find { |a| a.is_a?(Hash) && a.key?(:location_attributes) }
        location_attrs = nested[:location_attributes]

        expect(location_attrs).to include(:line1) # bare Address attribute
        expect(location_attrs.any? { |a| a.is_a?(Hash) && a.key?(:address_attributes) }).to be(true) # nested under Building
      end
    end
  end
end
