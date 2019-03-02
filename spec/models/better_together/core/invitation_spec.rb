require 'rails_helper'

module BetterTogether::Core
  RSpec.describe Invitation, type: :model do
    let(:invitation) { build(:better_together_core_invitation) }
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

    describe 'callbacks' do
      it { is_expected.to callback(:generate_bt_id).before(:validation) }
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
  end
end
