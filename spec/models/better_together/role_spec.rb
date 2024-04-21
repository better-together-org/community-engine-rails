# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe Role, type: :model do # rubocop:todo Metrics/BlockLength
    let(:role) { build(:better_together_role) }
    subject { role }

    describe 'has a valid factory' do
      it { is_expected.to be_valid }
    end

    describe 'ActiveRecord associations' do # rubocop:todo Lint/EmptyBlock
    end

    describe 'ActiveModel validations' do
      it { is_expected.to validate_presence_of(:name) }
    end

    describe 'callbacks' do # rubocop:todo Lint/EmptyBlock
    end

    # it_behaves_like 'a translatable record'
    it_behaves_like 'has_id'

    describe '.only_protected' do
      it { expect(described_class).to respond_to(:only_protected) }
      it 'scopes results to protected = true' do
        expect(described_class.only_protected.new).to have_attributes(protected: true)
      end
    end

    describe '#name' do
      it { is_expected.to respond_to(:name) }
    end

    describe '#to_s' do
      it { expect(role.to_s).to equal(role.name) }
    end

    describe '#description' do
      it { is_expected.to respond_to(:description) }
    end

    describe '#protected' do
      it { is_expected.to respond_to(:protected) }
    end

    describe '#position' do
      it { is_expected.to respond_to(:position) }
      it 'increments the max position when other roles exist' do
        existing_role = create(:role)
        role = create(:role)
        expect(role.position).to equal(existing_role.position + 1)
      end
    end

    describe '#resource_class' do
      it { is_expected.to respond_to(:resource_class) }
    end
  end
end
