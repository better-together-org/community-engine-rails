# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Invitation, type: :model do
  let(:community) { create(:better_together_community) }
  let(:inviter) { create(:better_together_person) }
  let(:email) { 'test@example.com' }

  describe 'duplicate invitation prevention' do
    context 'with pending invitation' do
      let!(:pending_invitation) do
        create(:better_together_invitation,
               invitable: community,
               inviter: inviter,
               invitee_email: email,
               status: 'pending')
      end

      it 'prevents creating duplicate invitation' do
        duplicate_invitation = build(:better_together_invitation,
                                     invitable: community,
                                     inviter: inviter,
                                     invitee_email: email,
                                     status: 'pending')

        expect(duplicate_invitation).not_to be_valid
        expect(duplicate_invitation.errors[:invitee_email]).to include(/has already been invited and the invitation is still pending/)
      end
    end

    context 'with accepted invitation' do
      let!(:accepted_invitation) do
        create(:better_together_invitation,
               invitable: community,
               inviter: inviter,
               invitee_email: email,
               status: 'accepted')
      end

      it 'prevents creating duplicate invitation' do
        duplicate_invitation = build(:better_together_invitation,
                                     invitable: community,
                                     inviter: inviter,
                                     invitee_email: email,
                                     status: 'pending')

        expect(duplicate_invitation).not_to be_valid
        expect(duplicate_invitation.errors[:invitee_email]).to include(/has already accepted an invitation/)
      end
    end

    context 'with declined invitation' do
      let!(:declined_invitation) do
        create(:better_together_invitation,
               invitable: community,
               inviter: inviter,
               invitee_email: email,
               status: 'declined')
      end

      it 'prevents creating duplicate invitation without force_resend' do
        duplicate_invitation = build(:better_together_invitation,
                                     invitable: community,
                                     inviter: inviter,
                                     invitee_email: email,
                                     status: 'pending')

        expect(duplicate_invitation).not_to be_valid
        expect(duplicate_invitation.errors[:invitee_email]).to include(/has previously declined an invitation/)
      end

      it 'allows creating invitation with force_resend' do
        duplicate_invitation = build(:better_together_invitation,
                                     invitable: community,
                                     inviter: inviter,
                                     invitee_email: email,
                                     status: 'pending')
        duplicate_invitation.force_resend = true

        expect(duplicate_invitation).to be_valid
      end
    end
  end
end
