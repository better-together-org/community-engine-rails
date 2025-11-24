# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe Geography::State, type: :model do
    subject(:state) { build(:better_together_geography_state) }

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
      it { is_expected.to have_db_column(:lock_version).of_type(:integer) }
      it { is_expected.to have_db_column(:created_at).of_type(:datetime) }
      it { is_expected.to have_db_column(:updated_at).of_type(:datetime) }
    end

    describe 'associations' do
      it { is_expected.to belong_to(:community).class_name('BetterTogether::Community') }
      it { is_expected.to belong_to(:country).class_name('BetterTogether::Geography::Country') }

      it do
        expect(subject).to have_many(:regions)
          .class_name('BetterTogether::Geography::Region')
      end

      it do
        expect(subject).to have_many(:settlements)
          .class_name('BetterTogether::Geography::Settlement')
      end
    end

    describe 'translations' do
      it 'translates name' do
        state.name = 'California'
        Mobility.with_locale(:es) do
          state.name = 'California'
        end
        expect(state.name).to eq('California')
        Mobility.with_locale(:es) do
          expect(state.name).to eq('California')
        end
      end

      it 'translates description' do
        state.description = 'A western state'
        Mobility.with_locale(:es) do
          state.description = 'Un estado occidental'
        end
        expect(state.description).to eq('A western state')
        Mobility.with_locale(:es) do
          expect(state.description).to eq('Un estado occidental')
        end
      end

      it 'translates slug' do
        state.identifier = 'california'
        state.save!
        expect(state.slug).to eq('california')
        Mobility.with_locale(:es) do
          state.slug = 'california-es'
          state.save!
          expect(state.slug).to eq('california-es')
        end
      end
    end

    describe 'validations' do
      it { is_expected.to validate_presence_of(:name) }

      it 'validates identifier uniqueness case-insensitively' do
        create(:better_together_geography_state, identifier: 'test-state')
        duplicate = build(:better_together_geography_state, identifier: 'TEST-STATE')
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:identifier]).to include('has already been taken')
      end
    end

    describe '#to_s' do
      it 'returns the state name' do
        state.name = 'Texas'
        expect(state.to_s).to eq('Texas')
      end
    end

    describe 'identifier generation' do
      it 'generates identifier from slug if not provided' do
        state.name = 'New York'
        state.save!
        expect(state.identifier).to be_present
      end
    end
  end
end
