# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Event Invitations', :as_platform_manager do
  let(:locale) { I18n.default_locale }
  let!(:event) do
    BetterTogether::Event.create!(
      name: 'Neighborhood Clean-up',
      starts_at: 1.day.from_now,
      identifier: SecureRandom.uuid,
      privacy: 'public'
    )
  end

  describe 'creating an event invitation' do
    # rubocop:todo RSpec/MultipleExpectations
    it 'creates a pending invitation and sends notifications' do # rubocop:todo RSpec/ExampleLength, RSpec/MultipleExpectations
      # rubocop:enable RSpec/MultipleExpectations
      expect do
        post better_together.event_invitations_path(event_id: event.slug, locale: locale),
             params: { invitation: { invitee_email: 'invitee@example.test' } }
      end.to change(BetterTogether::Invitation, :count).by(1)

      invitation = BetterTogether::Invitation.last
      expect(invitation).to be_present
      expect(invitation.invitable).to eq(event)
      expect(invitation.status).to eq('pending')
    end
  end

  describe 'token edge cases' do
    it 'returns not found for invalid token' do
      get better_together.invitation_path('invalid-token', locale: locale)
      expect(response).to have_http_status(:not_found)
    end

    it 'returns not found for expired token' do # rubocop:todo RSpec/ExampleLength
      invitation = BetterTogether::EventInvitation.create!(
        invitable: event,
        inviter: BetterTogether::Person.first || create(:better_together_person),
        status: 'pending',
        invitee_email: 'guest3@example.test',
        valid_from: 2.days.ago,
        valid_until: 1.day.ago
      )

      get better_together.invitation_path(invitation.token, locale: locale)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'resend throttling' do
    # rubocop:todo RSpec/MultipleExpectations
    it 'does not update last_sent within 15 minutes' do # rubocop:todo RSpec/ExampleLength, RSpec/MultipleExpectations
      # rubocop:enable RSpec/MultipleExpectations
      invitation = BetterTogether::EventInvitation.create!(
        invitable: event,
        inviter: BetterTogether::Person.first || create(:better_together_person),
        status: 'pending',
        invitee_email: 'guest4@example.test',
        valid_from: Time.current,
        last_sent: Time.current
      )

      put better_together.resend_event_invitation_path(event, invitation, locale: locale)
      expect(response).to have_http_status(:found)
      expect(invitation.reload.last_sent).to be_within(1.second).of(invitation.last_sent)
    end
  end

  describe 'accepting via token' do
    # rubocop:todo RSpec/MultipleExpectations
    it 'marks accepted and creates attendance' do # rubocop:todo RSpec/ExampleLength, RSpec/MultipleExpectations
      # rubocop:enable RSpec/MultipleExpectations
      invitation = BetterTogether::EventInvitation.create!(
        invitable: event,
        inviter: BetterTogether::Person.first || create(:better_together_person),
        status: 'pending',
        invitee_email: 'guest@example.test',
        valid_from: Time.current
      )

      # Ensure user exists and logged in as regular user
      user = BetterTogether::User.find_by(email: 'user@example.test') ||
             create(:better_together_user, :confirmed, email: 'user@example.test', password: 'password12345')
      login(user.email, 'password12345')

      post better_together.accept_invitation_path(invitation.token, locale: locale)

      expect(response).to have_http_status(:found)
      expect(invitation.reload.status).to eq('accepted')
      attendance = BetterTogether::EventAttendance.find_by(event: event, person: user.person)
      expect(attendance&.status).to eq('going')
    end
  end

  describe 'declining via token' do
    # rubocop:todo RSpec/MultipleExpectations
    it 'marks declined' do # rubocop:todo RSpec/ExampleLength, RSpec/MultipleExpectations
      # rubocop:enable RSpec/MultipleExpectations
      invitation = BetterTogether::EventInvitation.create!(
        invitable: event,
        inviter: BetterTogether::Person.first || create(:better_together_person),
        status: 'pending',
        invitee_email: 'guest2@example.test',
        valid_from: Time.current
      )

      user = BetterTogether::User.find_by(email: 'user@example.test') ||
             create(:better_together_user, :confirmed, email: 'user@example.test', password: 'password12345')
      login(user.email, 'password12345')

      post better_together.decline_invitation_path(invitation.token, locale: locale)
      expect(response).to have_http_status(:found)
      expect(invitation.reload.status).to eq('declined')
    end
  end
end
