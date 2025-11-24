# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe Geography::Settlement do
    subject(:settlement) { build(:better_together_geography_settlement) }

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
        expect(subject).to have_many(:regions)
          .through(:region_settlements)
          .source(:region)
      end
    end

    describe 'translations' do
      it 'translates name' do
        settlement.name = 'San Francisco'
        Mobility.with_locale(:es) do
          settlement.name = 'San Francisco'
        end
        expect(settlement.name).to eq('San Francisco')
        Mobility.with_locale(:es) do
          expect(settlement.name).to eq('San Francisco')
        end
      end

      it 'translates description' do
        settlement.description = 'A coastal city'
        Mobility.with_locale(:es) do
          settlement.description = 'Una ciudad costera'
        end
        expect(settlement.description).to eq('A coastal city')
        Mobility.with_locale(:es) do
          expect(settlement.description).to eq('Una ciudad costera')
        end
      end
    end

    describe 'validations' do
      it { is_expected.to validate_presence_of(:name) }

      it 'validates identifier uniqueness case-insensitively' do
        create(:better_together_geography_settlement, identifier: 'test-settlement')
        duplicate = build(:better_together_geography_settlement, identifier: 'TEST-SETTLEMENT')
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:identifier]).to include('has already been taken')
      end
    end

    describe '#to_s' do
      it 'returns the settlement name' do
        settlement.name = 'Los Angeles'
        expect(settlement.to_s).to eq('Los Angeles')
      end
    end

    describe 'optional associations' do
      it 'can be created without a country' do
        settlement.country = nil
        settlement.save!
        expect(settlement).to be_persisted
      end

      it 'can be created without a state' do
        settlement.state = nil
        settlement.save!
        expect(settlement).to be_persisted
      end
    end
  end
end
