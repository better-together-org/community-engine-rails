# frozen_string_literal: true

# spec/models/better_together/person_community_membership_spec.rb

require 'rails_helper'

module BetterTogether
  RSpec.describe PersonCommunityMembership, type: :model do
    subject(:person_community_membership) { build(:better_together_person_community_membership) }

    describe 'Factory' do
      it 'has a valid factory' do
        expect(person_community_membership).to be_valid
      end
    end

    describe 'ActiveRecord associations' do
      it { is_expected.to belong_to(:community) }
      it { is_expected.to belong_to(:member).class_name('BetterTogether::Person') }
      it { is_expected.to belong_to(:role) }
    end

    describe 'ActiveModel validations' do
      it { is_expected.to validate_uniqueness_of(:role).scoped_to(:community_id, :member_id) }
    end

    describe 'Attributes' do
      it { is_expected.to respond_to(:member_id) }
      it { is_expected.to respond_to(:community_id) }
      it { is_expected.to respond_to(:role_id) }
    end

    # Add tests for any additional model logic or methods
  end
end
