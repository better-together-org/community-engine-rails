# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Duplicate Invitation Prevention' do # rubocop:todo RSpec/MultipleDescribes
  let(:community) { create(:better_together_community) }
  let(:email) { 'test@example.com' }

  before do
    configure_host_platform
    login('user@example.com', 'password')
  end

  describe 'preventing duplicate invitations' do
    context 'when an invitation is pending' do
      let!(:pending_invitation) { create(:better_together_invitation, invitable: community, invitee_email: email, status: 'pending') }

      it 'prevents creating a new invitation' do
        post better_together.community_invitations_path(community),
             params: { invitation: { invitee_email: email }, locale: I18n.default_locale }

        expect(response).to redirect_to(community)
        expect(flash[:alert]).to match(/has already been invited and the invitation is still pending/)
      end
    end

    context 'when an invitation was accepted' do
      let!(:accepted_invitation) { create(:better_together_invitation, invitable: community, invitee_email: email, status: 'accepted') }

      it 'prevents creating a new invitation' do
        post better_together.community_invitations_path(community),
             params: { invitation: { invitee_email: email }, locale: I18n.default_locale }

        expect(response).to redirect_to(community)
        expect(flash[:alert]).to match(/has already accepted an invitation/)
      end
    end

    context 'when an invitation was declined without force_resend flag' do
      let!(:declined_invitation) { create(:better_together_invitation, invitable: community, invitee_email: email, status: 'declined') }

      it 'prevents creating a new invitation' do
        post better_together.community_invitations_path(community),
             params: { invitation: { invitee_email: email }, locale: I18n.default_locale }

        expect(response).to redirect_to(community)
        expect(flash[:alert]).to match(/has previously declined an invitation/)
      end
    end

    context 'when an invitation was declined with force_resend flag' do
      let!(:declined_invitation) { create(:better_together_invitation, invitable: community, invitee_email: email, status: 'declined') }

      it 'allows creating a new invitation and removes the old one' do
        expect do
          post better_together.community_invitations_path(community),
               params: { invitation: { invitee_email: email }, force_resend: '1', locale: I18n.default_locale }
        end.not_to change(BetterTogether::Invitation, :count)

        expect(response).to redirect_to(community)
        expect(flash[:notice]).to match(/invitation.*sent/i)

        # Old invitation should be deleted, new one should be pending
        expect(declined_invitation.reload).to be_pending
        expect(BetterTogether::Invitation.where(invitable: community, invitee_email: email, status: 'declined')).to be_empty
      end
    end
  end
end

describe 'with existing user' do
  let(:person) { create(:better_together_person) }

  context 'when an invitation is pending' do
    let!(:pending_invitation) { create(:better_together_invitation, invitable: community, invitee: person, status: 'pending') }

    it 'prevents creating a new invitation' do
      post better_together.community_invitations_path(community),
           params: { invitation: { invitee_id: person.id }, locale: I18n.default_locale }

      expect(response).to redirect_to(community)
      expect(flash[:alert]).to match(/has already been invited and the invitation is still pending/)
    end
  end

  context 'when an invitation to person was declined with force_resend flag' do
    let!(:declined_invitation) { create(:better_together_invitation, invitable: community, invitee: person, status: 'declined') }

    it 'allows creating a new invitation and removes the old one' do
      expect do
        post better_together.community_invitations_path(community),
             params: { invitation: { invitee_id: person.id }, force_resend: '1', locale: I18n.default_locale }
      end.not_to change(BetterTogether::Invitation, :count)

      expect(response).to redirect_to(community)
      expect(flash[:notice]).to match(/invitation.*sent/i)

      # Old invitation should be deleted, new one should be pending
      expect(declined_invitation.reload).to be_pending
      expect(BetterTogether::Invitation.where(invitable: community, invitee: person, status: 'declined')).to be_empty
    end
  end
end
