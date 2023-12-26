# spec/models/better_together/navigation_area_spec.rb

require 'rails_helper'

module BetterTogether
  RSpec.describe NavigationArea, type: :model do
    subject(:navigation_area) { build(:better_together_navigation_area) }

    describe 'Factory' do
      it 'has a valid factory' do
        expect(navigation_area).to be_valid
      end
    end

    describe 'ActiveRecord associations' do
      it { is_expected.to belong_to(:navigable).optional }
      it { is_expected.to have_many(:navigation_items).dependent(:destroy) }
    end

    describe 'ActiveModel validations' do
      it { is_expected.to validate_presence_of(:name) }
      it { is_expected.to validate_uniqueness_of(:name) }
      # it { is_expected.to validate_inclusion_of(:visible).in_array([true, false]) }
      it { is_expected.to validate_length_of(:style).is_at_most(255).allow_blank }
    end

    describe 'Attributes' do
      it { is_expected.to respond_to(:name) }
      it { is_expected.to respond_to(:style) }
      it { is_expected.to respond_to(:visible) }
      it { is_expected.to respond_to(:slug) }
      it { is_expected.to respond_to(:navigable_type) }
      it { is_expected.to respond_to(:navigable_id) }
      it { is_expected.to respond_to(:protected) }
    end

    describe 'Scopes' do
      describe '.visible' do
        it 'returns only visible navigation areas' do
          create(:better_together_navigation_area, visible: true)
          create(:better_together_navigation_area, visible: false)
          expect(NavigationArea.visible.count).to eq(1)
        end
      end
    end

    # Add tests for any additional model logic or methods
  end
end
