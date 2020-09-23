require 'rails_helper'

module BetterTogether
  RSpec.describe Role, type: :model do
    let(:role) { build(:better_together_role) }
    subject { role }

    describe 'has a valid factory' do
      it { is_expected.to be_valid }
    end

    describe 'ActiveRecord associations' do
    end

    describe 'ActiveModel validations' do
      it { is_expected.to validate_presence_of(:name) }
    end

    describe 'callbacks' do
    end

    it_behaves_like 'a translatable record'
    it_behaves_like 'has_bt_id'

    describe '.reserved' do
      it { expect(described_class).to respond_to(:reserved) }
      it 'scopes results to reserved = true' do
        expect(described_class.reserved.new).to have_attributes(reserved: true)
      end
    end

    describe '#name' do
      it { is_expected.to respond_to(:name) }
    end

    describe '#description' do
      it { is_expected.to respond_to(:description) }
    end

    describe '#reserved' do
      it { is_expected.to respond_to(:reserved) }
    end

    describe '#sort_order' do
      it { is_expected.to respond_to(:sort_order) }
    end

    describe '#target_class' do
      it { is_expected.to respond_to(:target_class) }
    end
  end
end
