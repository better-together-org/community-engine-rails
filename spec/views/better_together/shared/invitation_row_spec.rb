# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/shared/invitation_row' do
  let(:community) { create(:better_together_community) }
  let(:inviter) { create(:better_together_person) }

  before do
    # Define the policy method for view testing
    def view.policy(_record)
      mock_policy = Object.new
      def mock_policy.resend? = true
      def mock_policy.destroy? = true
      mock_policy
    end
  end

  context 'with declined invitation' do
    let(:declined_invitation) do
      create(:better_together_invitation,
             invitable: community,
             inviter: inviter,
             invitee_email: 'declined@example.com',
             status: 'declined')
    end

    it 'renders special resend button for declined invitations' do
      render partial: 'better_together/shared/invitation_row',
             locals: {
               invitation_row: declined_invitation,
               resend_path: '/resend/path',
               destroy_path: '/destroy/path'
             }

      expect(rendered).to include('btn-outline-warning')
      expect(rendered).to include(t('better_together.invitations.resend_declined', default: 'Resend to Declined'))
      expect(rendered).to include(t('better_together.invitations.confirm_resend_declined'))
      expect(rendered).to include('force_resend')
    end
  end

  context 'with pending invitation' do
    let(:pending_invitation) do
      create(:better_together_invitation,
             invitable: community,
             inviter: inviter,
             invitee_email: 'pending@example.com',
             status: 'pending')
    end

    it 'renders normal resend button for pending invitations' do
      render partial: 'better_together/shared/invitation_row',
             locals: {
               invitation_row: pending_invitation,
               resend_path: '/resend/path',
               destroy_path: '/destroy/path'
             }

      expect(rendered).to include('btn-outline-secondary')
      expect(rendered).to include(t('globals.resend', default: 'Resend'))
      expect(rendered).not_to include('btn-outline-warning')
      expect(rendered).not_to include('force_resend')
    end
  end

  context 'with accepted invitation' do
    let(:accepted_invitation) do
      create(:better_together_invitation,
             invitable: community,
             inviter: inviter,
             invitee_email: 'accepted@example.com',
             status: 'accepted')
    end

    it 'renders normal resend button for accepted invitations' do
      render partial: 'better_together/shared/invitation_row',
             locals: {
               invitation_row: accepted_invitation,
               resend_path: '/resend/path',
               destroy_path: '/destroy/path'
             }

      expect(rendered).to include('btn-outline-secondary')
      expect(rendered).to include(t('globals.resend', default: 'Resend'))
      expect(rendered).not_to include('btn-outline-warning')
      expect(rendered).not_to include('force_resend')
    end
  end
end
