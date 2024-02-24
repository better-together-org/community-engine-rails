# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe Invitation, type: :model do
    let(:invitation) { build(:better_together_invitation) }
    subject { invitation }

    describe 'has a valid factory' do
      it { is_expected.to be_valid }
    end

    describe 'ActiveRecord associations' do
      it { is_expected.to belong_to(:inviter) }
      it { is_expected.to belong_to(:invitee) }
      it { is_expected.to belong_to(:invitable) }
      it { is_expected.to belong_to(:role) }
    end

    describe 'ActiveModel validations' do
    end

    describe '#status' do
      it 'is a string enum' do
        is_expected.to(
          define_enum_for(:status).with_values(
            accepted: 'accepted',
            declined: 'declined',
            pending: 'pending'
          ).backed_by_column_of_type(:string)
        )
      end
    end

    describe '#valid_from' do
      it { is_expected.to respond_to(:valid_from) }
      it { is_expected.to respond_to(:valid_until) }
    end

    it_behaves_like 'has_bt_id'
  end
end
