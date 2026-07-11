# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Invitation do
  subject(:invitation) do
    build(:better_together_invitation, invitable: community, inviter: inviter)
  end

  let(:community) { create(:better_together_community) }
  let(:inviter) { create(:better_together_person) }

  describe 'validations' do
    it 'is valid with required attributes' do
      expect(invitation).to be_valid
    end

    it 'raises when assigned an unknown status value' do
      expect { invitation.status = 'unknown' }.to raise_error(ArgumentError)
    end

    it 'requires locale' do
      invitation.locale = nil
      expect(invitation).not_to be_valid
    end

    it 'rejects unknown locale' do
      invitation.locale = 'zz'
      expect(invitation).not_to be_valid
    end

    it 'requires either invitee or invitee_email' do
      invitation.invitee = nil
      invitation.invitee_email = nil
      expect(invitation).not_to be_valid
      expect(invitation.errors[:base]).to be_present
    end
  end

  describe 'token auto-generation' do
    it 'auto-generates a token before validation' do
      inv = build(:better_together_invitation, invitable: community, inviter: inviter)
      inv.token = nil
      inv.valid?
      expect(inv.token).to be_present
    end
  end

  describe 'STATUS_VALUES constant' do
    it 'includes pending, accepted, declined' do
      expect(described_class::STATUS_VALUES.keys).to contain_exactly(:pending, :accepted, :declined)
    end
  end

  describe '#invitation_type' do
    it 'returns :email when invitee_email is set and invitee is nil' do
      expect(invitation.invitation_type).to eq(:email)
    end

    it 'returns :person when invitee is set' do
      invitee = create(:better_together_person)
      inv = build(:better_together_invitation, :with_invitee, invitable: community, inviter: inviter,
                                                              invitee: invitee)
      expect(inv.invitation_type).to eq(:person)
    end
  end

  describe '#for_email?' do
    it 'returns true for email-based invitation' do
      expect(invitation.for_email?).to be true
    end
  end

  describe '#for_existing_user?' do
    it 'returns false for email-based invitation' do
      expect(invitation.for_existing_user?).to be false
    end
  end

  describe '#accept!' do
    it 'sets status to accepted' do
      inv = create(:better_together_invitation, invitable: community, inviter: inviter)
      inv.accept!
      expect(inv.reload.status).to eq('accepted')
    end
  end

  describe '#decline!' do
    it 'sets status to declined' do
      inv = create(:better_together_invitation, invitable: community, inviter: inviter)
      inv.decline!
      expect(inv.reload.status).to eq('declined')
    end
  end

  describe 'duplicate invitation prevention' do
    it 'rejects a second pending email invitation to the same invitable' do
      first = create(:better_together_invitation, invitable: community, inviter: inviter,
                                                  invitee_email: 'duplicate@example.com')
      expect(first).to be_persisted
      duplicate = build(:better_together_invitation, invitable: community, inviter: inviter,
                                                     invitee_email: 'duplicate@example.com')
      expect(duplicate).not_to be_valid
    end

    it 'allows resending to a declined invitee when force_resend is true' do
      declined = create(:better_together_invitation, :declined, invitable: community, inviter: inviter,
                                                                invitee_email: 'declined@example.com')
      expect(declined).to be_persisted
      resend = build(:better_together_invitation, invitable: community, inviter: inviter,
                                                  invitee_email: 'declined@example.com')
      resend.force_resend = true
      expect(resend).to be_valid
    end
  end

  describe 'scopes' do
    it '.pending returns only pending invitations' do
      pending_inv = create(:better_together_invitation, invitable: community, inviter: inviter,
                                                        invitee_email: 'scope_pending@example.com')
      accepted_inv = create(:better_together_invitation, :accepted, invitable: community,
                                                                    inviter: inviter,
                                                                    invitee_email: 'scope_accepted@example.com')
      expect(described_class.pending).to include(pending_inv)
      expect(described_class.pending).not_to include(accepted_inv)
    end

    it '.not_expired returns invitations that have not expired' do
      active = create(:better_together_invitation, invitable: community, inviter: inviter,
                                                   invitee_email: 'active@example.com')
      expired = create(:better_together_invitation, :expired, invitable: community, inviter: inviter,
                                                              invitee_email: 'expired@example.com')
      expect(described_class.not_expired).to include(active)
      expect(described_class.not_expired).not_to include(expired)
    end
  end
end
