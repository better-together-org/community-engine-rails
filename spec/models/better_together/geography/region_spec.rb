# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe Geography::Region, type: :model do
    subject(:region) { build(:better_together_geography_region) }

    describe 'concerns' do
      it 'includes Geospatial::One' do
        expect(described_class.ancestors).to include(BetterTogether::Geography::Geospatial::One)
      end

      it 'includes Identifier' do
        expect(described_class.ancestors).to include(BetterTogether::Identifier)
      end

      it 'includes Protected' do
        expect(described_class.ancestors).to include(BetterTogether::Protected)
      end

      it 'includes PrimaryCommunity' do
        expect(described_class.ancestors).to include(BetterTogether::PrimaryCommunity)
      end
    end

    describe 'database' do
      it { is_expected.to have_db_column(:id).of_type(:uuid) }
      it { is_expected.to have_db_column(:identifier).of_type(:string) }
      it { is_expected.to have_db_column(:protected).of_type(:boolean) }
      it { is_expected.to have_db_column(:community_id).of_type(:uuid) }
      it { is_expected.to have_db_column(:country_id).of_type(:uuid) }
      it { is_expected.to have_db_column(:state_id).of_type(:uuid) }
      it { is_expected.to have_db_column(:lock_version).of_type(:integer) }
      it { is_expected.to have_db_column(:created_at).of_type(:datetime) }
      it { is_expected.to have_db_column(:updated_at).of_type(:datetime) }
    end

    describe 'associations' do
      it { is_expected.to belong_to(:community).class_name('BetterTogether::Community') }
      it { is_expected.to belong_to(:country).class_name('BetterTogether::Geography::Country').optional }
      it { is_expected.to belong_to(:state).class_name('BetterTogether::Geography::State').optional }

      it do
        expect(subject).to have_many(:region_settlements)
          .class_name('BetterTogether::Geography::RegionSettlement')
      end

      it do
        expect(subject).to have_many(:settlements)
          .through(:region_settlements)
          .source(:settlement)
      end
    end

    describe 'translations' do
      it 'translates name' do
        region.name = 'Bay Area'
        Mobility.with_locale(:es) do
          region.name = 'Área de la Bahía'
        end
        expect(region.name).to eq('Bay Area')
        Mobility.with_locale(:es) do
          expect(region.name).to eq('Área de la Bahía')
        end
      end

      it 'translates description' do
        region.description = 'A metropolitan region'
        Mobility.with_locale(:es) do
          region.description = 'Una región metropolitana'
        end
        expect(region.description).to eq('A metropolitan region')
        Mobility.with_locale(:es) do
          expect(region.description).to eq('Una región metropolitana')
        end
      end
    end

    describe 'validations' do
      it { is_expected.to validate_presence_of(:name) }

      it 'validates identifier uniqueness case-insensitively' do
        create(:better_together_geography_region, identifier: 'test-region')
        duplicate = build(:better_together_geography_region, identifier: 'TEST-REGION')
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:identifier]).to include('has already been taken')
      end
    end

    describe '#to_s' do
      it 'returns the region name' do
        region.name = 'Silicon Valley'
        expect(region.to_s).to eq('Silicon Valley')
      end
    end

    describe 'optional associations' do
      it 'can be created without a country' do
        region.country = nil
        region.save!
        expect(region).to be_persisted
      end

      it 'can be created without a state' do
        region.state = nil
        region.save!
        expect(region).to be_persisted
      end
    end
  end
end
