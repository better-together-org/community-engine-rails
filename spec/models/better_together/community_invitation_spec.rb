# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe CommunityInvitation do
    subject(:community_invitation) { create(:better_together_community_invitation) }

    describe 'Factory' do
      it 'has a valid factory' do
        expect(community_invitation).to be_valid
      end
    end

    describe 'ActiveRecord associations' do
      it { is_expected.to belong_to(:invitable).required }
      it { is_expected.to belong_to(:inviter).required }
      it { is_expected.to belong_to(:invitee).optional }
      it { is_expected.to belong_to(:role).optional }
    end

    describe 'Validations' do
      it { is_expected.to validate_presence_of(:locale) }
      it { is_expected.to validate_inclusion_of(:locale).in_array(I18n.available_locales.map(&:to_s)) }

      describe 'invitee presence validation' do
        it 'requires either invitee or invitee_email' do
          invitation = build(:better_together_community_invitation, invitee: nil, invitee_email: '')
          expect(invitation).not_to be_valid
          expect(invitation.errors[:base]).to include('must have either an invitee or invitee email')
        end
      end
    end

    describe '#community' do
      it 'returns the invitable community' do
        community = create(:better_together_community)
        invitation = create(:better_together_community_invitation, invitable: community)
        expect(invitation.community).to eq(community)
      end
    end

    describe '#invitation_type' do
      it 'returns :person for person invitations' do
        invitation = build(:better_together_community_invitation, :with_invitee)
        expect(invitation.invitation_type).to eq(:person)
      end

      it 'returns :email for email invitations' do
        invitation = build(:better_together_community_invitation, invitee: nil)
        expect(invitation.invitation_type).to eq(:email)
      end
    end

    describe '#accept!' do
      let(:community) { create(:better_together_community) }
      let(:person) { create(:better_together_person) }
      let(:role) { BetterTogether::Role.find_by(identifier: 'community_member') }
      let(:invitation) { create(:better_together_community_invitation, invitable: community, role: role) }

      it 'changes status to accepted' do
        expect { invitation.accept!(invitee_person: person) }.to change { invitation.reload.status }.to('accepted')
      end
    end

    describe '#decline!' do
      it 'changes status to declined' do
        expect { community_invitation.decline! }.to change { community_invitation.reload.status }.to('declined')
      end
    end
  end
end
