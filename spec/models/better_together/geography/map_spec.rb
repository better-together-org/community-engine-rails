# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe Geography::Map do
    subject(:map) { build(:better_together_geography_map) }

    describe 'concerns' do
      it 'includes Creatable' do
        expect(described_class.ancestors).to include(BetterTogether::Creatable)
      end

      it 'includes FriendlySlug' do
        expect(described_class.ancestors).to include(BetterTogether::FriendlySlug)
      end

      it 'includes Identifier' do
        expect(described_class.ancestors).to include(BetterTogether::Identifier)
      end

      it 'includes Privacy' do
        expect(described_class.ancestors).to include(BetterTogether::Privacy)
      end

      it 'includes Protected' do
        expect(described_class.ancestors).to include(BetterTogether::Protected)
      end

      it 'includes Viewable' do
        expect(described_class.ancestors).to include(BetterTogether::Viewable)
      end
    end

    describe 'database' do
      it { is_expected.to have_db_column(:id).of_type(:uuid) }
      it { is_expected.to have_db_column(:identifier).of_type(:string) }
      it { is_expected.to have_db_column(:zoom).of_type(:integer) }
      it { is_expected.to have_db_column(:protected).of_type(:boolean) }
      it { is_expected.to have_db_column(:creator_id).of_type(:uuid) }
      it { is_expected.to have_db_column(:privacy).of_type(:string) }
      it { is_expected.to have_db_column(:mappable_id).of_type(:uuid) }
      it { is_expected.to have_db_column(:mappable_type).of_type(:string) }
      it { is_expected.to have_db_column(:lock_version).of_type(:integer) }
      it { is_expected.to have_db_column(:created_at).of_type(:datetime) }
      it { is_expected.to have_db_column(:updated_at).of_type(:datetime) }
    end

    describe 'associations' do
      it { is_expected.to belong_to(:creator).class_name('BetterTogether::Person') }
      it { is_expected.to belong_to(:mappable).optional }
    end

    describe 'translations' do
      # NOTE: This test will pass after running the title migration
      # The type: :string parameter ensures new records use string_translations table
      it 'translates title' do
        skip 'Mobility key-value backend does not support locale switching for unsaved records'

        map.title = 'World Map'
        expect(map.title).to eq('World Map')

        Mobility.with_locale(:es) do
          map.title = 'Mapa del Mundo'
          expect(map.title).to eq('Mapa del Mundo')
        end

        # After exiting the es locale block, should still be World Map in default locale
        expect(map.title).to eq('World Map')
      end

      it 'translates description with Action Text' do
        map.description = '<p>A comprehensive map</p>'
        expect(map.description).to be_a(ActionText::RichText)
      end
    end

    describe 'validations' do
      it { is_expected.to validate_numericality_of(:zoom).only_integer.is_greater_than(0) }

      it 'validates center presence' do
        # Since center has a default_center fallback in the getter,
        # we verify the validation exists rather than testing the fallback behavior
        expect(described_class.validators_on(:center).map(&:class)).to include(ActiveRecord::Validations::PresenceValidator)
      end
    end

    describe 'default center' do
      it 'sets default center before validation on create' do
        new_map = build(:better_together_geography_map, center: nil)
        new_map.valid?
        expect(new_map.center).to be_present
      end

      it 'uses ENV defaults or fallback coordinates' do
        new_map = build(:better_together_geography_map, center: nil)
        default = new_map.default_center
        expect(default).to be_a(RGeo::Geographic::SphericalPointImpl)
      end
    end

    describe '#center' do
      it 'returns set center if present' do
        factory = RGeo::Geographic.spherical_factory(srid: 4326)
        custom_center = factory.point(-122.4194, 37.7749)
        map.center = custom_center
        expect(map.center).to eq(custom_center)
      end

      it 'returns default_center if not set' do
        map.center = nil
        expect(map.center).to eq(map.default_center)
      end
    end

    describe '.permitted_attributes' do
      it 'includes map-specific attributes' do
        attrs = described_class.permitted_attributes
        expect(attrs).to include(:type, :zoom, :center)
      end
    end
  end
end
