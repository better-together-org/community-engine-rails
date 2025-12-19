# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::EventInvitation do
  describe 'Factory' do
    subject(:event_invitation) { create(:better_together_event_invitation) }

    it 'has a valid factory' do
      expect(event_invitation).to be_valid
    end
  end

  describe 'ActiveRecord associations' do
    it { is_expected.to belong_to(:invitable).required }
    it { is_expected.to belong_to(:inviter).required }
    it { is_expected.to belong_to(:invitee).optional }
    it { is_expected.to belong_to(:role).optional }
  end

  describe 'Validations' do
    it { is_expected.to validate_inclusion_of(:locale).in_array(I18n.available_locales.map(&:to_s)) }
    it { is_expected.to validate_presence_of(:locale) }

    it 'requires either invitee or invitee_email when both are blank' do
      invitation = build(:better_together_event_invitation, invitee: nil, invitee_email: '')
      expect(invitation).not_to be_valid
      expect(invitation.errors[:base]).to include('must have either an invitee or invitee email')
    end

    describe 'invitee uniqueness for event' do
      let(:event) { create(:better_together_event) }

      it 'prevents duplicate invitations to the same event' do
        invitation = create(:better_together_event_invitation, invitable: event)
        duplicate = build(:better_together_event_invitation,
                          invitable: event,
                          invitee_email: invitation.invitee_email)

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:invitee_email]).to include('has already been taken')
      end
    end
  end

  describe '#event' do
    it 'returns the invitable event' do
      event_invitation = create(:better_together_event_invitation)
      expect(event_invitation.event).to eq(event_invitation.invitable)
    end
  end

  describe '#after_accept!' do
    let(:event_invitation) { create(:better_together_event_invitation, :with_invitee) }
    let(:person) { event_invitation.invitee }

    it 'completes the invitation acceptance process' do
      # TODO: Add specific expectations for your event acceptance logic
      # For example:
      # expect { event_invitation.after_accept!(invitee_person: person) }
      #   .to change { event_invitation.event.event_memberships.count }.by(1)

      expect { event_invitation.after_accept!(invitee_person: person) }.not_to raise_error
    end
  end

  describe '#url_for_review' do
    it 'returns the review URL for the invitation' do
      event_invitation = create(:better_together_event_invitation)
      expected_url = BetterTogether::Engine.routes.url_helpers.event_url(
        event_invitation.invitable.slug,
        locale: event_invitation.locale,
        invitation_token: event_invitation.token
      )

      expect(event_invitation.url_for_review).to eq(expected_url)
    end
  end

  describe '#decline!' do
    it 'changes status to declined' do
      event_invitation = create(:better_together_event_invitation)
      expect { event_invitation.decline! }.to change { event_invitation.reload.status }.to('declined')
    end
  end
end
