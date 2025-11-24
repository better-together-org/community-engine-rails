# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe Geography::Continent do
    subject(:continent) { build(:better_together_geography_continent) }

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
      it { is_expected.to have_db_column(:lock_version).of_type(:integer) }
      it { is_expected.to have_db_column(:created_at).of_type(:datetime) }
      it { is_expected.to have_db_column(:updated_at).of_type(:datetime) }
    end

    describe 'associations' do
      it { is_expected.to belong_to(:community).class_name('BetterTogether::Community') }

      it do
        expect(subject).to have_many(:country_continents)
          .class_name('BetterTogether::Geography::CountryContinent')
          .dependent(:destroy)
      end

      it do
        expect(subject).to have_many(:countries)
          .through(:country_continents)
          .class_name('BetterTogether::Geography::Country')
      end
    end

    describe 'translations' do
      it 'translates name' do
        continent.name = 'North America'
        Mobility.with_locale(:es) do
          continent.name = 'América del Norte'
        end
        expect(continent.name).to eq('North America')
        Mobility.with_locale(:es) do
          expect(continent.name).to eq('América del Norte')
        end
      end

      it 'translates description' do
        continent.description = 'A large continent'
        Mobility.with_locale(:es) do
          continent.description = 'Un gran continente'
        end
        expect(continent.description).to eq('A large continent')
        Mobility.with_locale(:es) do
          expect(continent.description).to eq('Un gran continente')
        end
      end

      it 'translates slug' do
        continent.identifier = 'north-america'
        continent.save!
        expect(continent.slug).to eq('north-america')
        Mobility.with_locale(:es) do
          continent.slug = 'america-del-norte'
          continent.save!
          expect(continent.slug).to eq('america-del-norte')
        end
      end
    end

    describe 'validations' do
      it { is_expected.to validate_presence_of(:name) }

      it 'validates identifier uniqueness case-insensitively' do
        create(:better_together_geography_continent, identifier: 'test-continent')
        duplicate = build(:better_together_geography_continent, identifier: 'TEST-CONTINENT')
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:identifier]).to include('has already been taken')
      end
    end

    describe '#to_s' do
      it 'returns the continent name' do
        continent.name = 'Europe'
        expect(continent.to_s).to eq('Europe')
      end
    end

    describe 'identifier generation' do
      it 'generates identifier from slug if not provided' do
        continent.name = 'South America'
        continent.save!
        expect(continent.identifier).to be_present
      end
    end
  end
end
