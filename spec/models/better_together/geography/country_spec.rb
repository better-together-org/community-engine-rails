# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe Geography::Country do
    subject(:country) { build(:better_together_geography_country) }

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
      subject(:country) { build(:better_together_geography_country) }

      it { is_expected.to belong_to(:community).class_name('BetterTogether::Community') }

      it do
        expect(country).to have_many(:country_continents)
          .class_name('BetterTogether::Geography::CountryContinent')
          .dependent(:destroy)
      end

      it do
        expect(country).to have_many(:continents)
          .through(:country_continents)
          .class_name('BetterTogether::Geography::Continent')
      end

      it do
        expect(country).to have_many(:states)
          .class_name('BetterTogether::Geography::State')
          .dependent(:nullify)
      end
    end

    describe 'translations' do
      it 'translates name' do
        country.name = 'United States'
        Mobility.with_locale(:es) do
          country.name = 'Estados Unidos'
        end
        expect(country.name).to eq('United States')
        Mobility.with_locale(:es) do
          expect(country.name).to eq('Estados Unidos')
        end
      end

      it 'translates description' do
        country.description = 'A large country'
        Mobility.with_locale(:es) do
          country.description = 'Un gran país'
        end
        expect(country.description).to eq('A large country')
        Mobility.with_locale(:es) do
          expect(country.description).to eq('Un gran país')
        end
      end

      it 'translates slug' do
        country.identifier = 'united-states'
        country.save!
        expect(country.slug).to eq('united-states')
        Mobility.with_locale(:es) do
          country.slug = 'estados-unidos'
          country.save!
          expect(country.slug).to eq('estados-unidos')
        end
      end
    end

    describe 'validations' do
      it { is_expected.to validate_presence_of(:name) }

      it 'validates identifier uniqueness case-insensitively' do
        create(:better_together_geography_country, identifier: 'test-country')
        duplicate = build(:better_together_geography_country, identifier: 'TEST-COUNTRY')
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:identifier]).to include('has already been taken')
      end
    end

    describe '#to_s' do
      it 'returns the country name' do
        country.name = 'Canada'
        expect(country.to_s).to eq('Canada')
      end
    end

    describe 'identifier generation' do
      it 'generates identifier from slug if not provided' do
        country.name = 'Mexico'
        country.save!
        expect(country.identifier).to be_present
      end
    end
  end
end
