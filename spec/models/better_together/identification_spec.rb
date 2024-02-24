# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  describe Identification do
    let(:identification) { create(:identification) }
    subject { identification }

    describe 'has a valid factory' do
      it { is_expected.to be_valid }
    end

    describe 'ActiveRecord associations' do
      it { is_expected.to belong_to(:identity) }
      it { is_expected.to belong_to(:agent) }
    end

    describe 'ActiveModel validations' do
      it { is_expected.to validate_presence_of(:identity) }
      it { is_expected.to validate_presence_of(:agent) }
      # it { is_expected.to validate_inclusion_of(:active).in([true, false]) }
      # it { is_expected.to validate_uniqueness_of(:active).scoped_to(%i(aent_type agent_id)) }
      # it { is_expected.to validate_uniqueness_of(:identity_id).scoped_to(%i(identity_type agent_type agent_id)) }
    end

    describe 'callbacks' do
    end

    describe '#active' do
      it { is_expected.to respond_to(:active) }
    end

    it_behaves_like 'has_bt_id'
  end
end
