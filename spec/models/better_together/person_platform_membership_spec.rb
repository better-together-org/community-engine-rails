# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe PersonPlatformMembership do
    subject(:person_platform_membership) { build(:better_together_person_platform_membership) }

    describe 'Factory' do
      it 'has a valid factory' do
        expect(person_platform_membership).to be_valid
      end
    end

    describe 'ActiveRecord associations' do
      it { is_expected.to belong_to(:joinable) }
      it { is_expected.to belong_to(:member).class_name('BetterTogether::Person') }
      it { is_expected.to belong_to(:role) }
    end

    describe 'Attributes' do
      it { is_expected.to respond_to(:member_id) }
      it { is_expected.to respond_to(:joinable_id) }
      it { is_expected.to respond_to(:role_id) }
    end

    describe 'notifications' do
      it 'creates a membership created notification' do
        membership = build(:better_together_person_platform_membership)

        expect do
          membership.save!
        end.to change(Noticed::Notification, :count).by(1)

        notification = Noticed::Notification.last
        expect(notification.recipient).to eq(membership.member)
        expect(notification.event.type).to eq('BetterTogether::MembershipCreatedNotifier')
      end
    end
  end
end
