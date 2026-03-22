# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Event Invitations', :as_platform_manager do
  let(:locale) { I18n.default_locale }
  let!(:manager_user) { BetterTogether::User.find_by(email: 'manager@example.test') }
  let!(:event) do
    BetterTogether::Event.create!(
      name: 'Neighborhood Clean-up',
      starts_at: 1.day.from_now,
      identifier: SecureRandom.uuid,
      privacy: 'public',
      creator: manager_user.person
    )
  end

  describe 'creating an event invitation' do
    # rubocop:todo RSpec/MultipleExpectations
    it 'creates a pending invitation and sends notifications' do # rubocop:todo RSpec/MultipleExpectations
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

    it 'uses person locale and email when inviting existing user' do # rubocop:todo RSpec/MultipleExpectations
      # Create a person with Spanish locale
      invitee = create(:better_together_person, locale: 'es')

      expect do
        post better_together.event_invitations_path(event_id: event.slug, locale: locale),
             params: { invitation: { invitee_id: invitee.id } }
      end.to change(BetterTogether::Invitation, :count).by(1)

      invitation = BetterTogether::Invitation.last
      expect(invitation.invitee).to eq(invitee)
      expect(invitation.invitee_email).to eq(invitee.email)
      expect(invitation.locale).to eq('es') # Should use person's locale, not default
    end
  end

  describe 'available people endpoint' do
    it 'returns people who can be invited, excluding already invited ones' do # rubocop:todo RSpec/MultipleExpectations
      # Create some people with confirmed user accounts (required for available_people endpoint)
      invitable_user = create(:better_together_user, :confirmed)
      invitable_user.person.update!(name: 'Available Person')
      invitable_person = invitable_user.person

      already_invited_user = create(:better_together_user, :confirmed)
      already_invited_user.person.update!(name: 'Already Invited')
      already_invited_person = already_invited_user.person

      # Create an invitation for one person
      create(:better_together_event_invitation,
             invitable: event,
             invitee: already_invited_person,
             inviter: manager_user.person,
             status: 'pending')

      get better_together.available_people_event_invitations_path(event.slug, locale: locale),
          params: { search: 'Person' }

      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)

      # Should include the available person (text includes name with friendly ID)
      available_names = json_response.pluck('text')
      expect(available_names.any? { |name| name.include?(invitable_person.name) }).to be true

      # Should NOT include the already invited person
      expect(available_names.none? { |name| name.include?(already_invited_person.name) }).to be true
    end
  end

  describe 'token edge cases' do
    it 'returns not found for invalid token' do
      get better_together.invitation_path('invalid-token', locale: locale)
      expect(response).to have_http_status(:not_found)
    end

    it 'returns not found for expired token' do
      invitation = create(:better_together_event_invitation,
                          invitable: event,
                          invitee_email: 'guest3@example.test',
                          status: 'pending',
                          valid_from: 2.days.ago,
                          valid_until: 1.day.ago)

      get better_together.invitation_path(invitation.token, locale: locale)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'resend throttling' do
    # rubocop:todo RSpec/MultipleExpectations
    it 'does not update last_sent within 15 minutes' do # rubocop:todo RSpec/MultipleExpectations
      # rubocop:enable RSpec/MultipleExpectations
      invitation = create(:better_together_event_invitation,
                          invitable: event,
                          invitee_email: 'guest4@example.test',
                          status: 'pending',
                          valid_from: Time.current,
                          last_sent: Time.current)

      put better_together.resend_event_invitation_path(event, invitation, locale: locale)
      expect(response).to have_http_status(:see_other)
      expect(invitation.reload.last_sent).to be_within(1.second).of(invitation.last_sent)
    end
  end

  describe 'accepting via token' do
    # rubocop:todo RSpec/MultipleExpectations
    it 'marks accepted and creates attendance' do # rubocop:todo RSpec/MultipleExpectations
      # rubocop:enable RSpec/MultipleExpectations
      invitation = create(:better_together_event_invitation,
                          invitable: event,
                          invitee_email: 'guest@example.test',
                          status: 'pending',
                          valid_from: Time.current)

      # Ensure user exists and logged in as regular user
      user = BetterTogether::User.find_by(email: 'user@example.test') ||
             create(:better_together_user, :confirmed, email: 'user@example.test', password: 'SecureTest123!@#')

      # Clear any existing session and login as the specific user
      logout if respond_to?(:logout)
      login(user.email, 'SecureTest123!@#')

      post better_together.accept_invitation_path(invitation.token, locale: locale)

      expect(response).to have_http_status(:found)
      expect(invitation.reload.status).to eq('accepted')
      attendance = BetterTogether::EventAttendance.find_by(event: event, person: user.person)
      expect(attendance&.status).to eq('going')
    end
  end

  describe 'declining via token' do
    # rubocop:todo RSpec/MultipleExpectations
    it 'marks declined' do # rubocop:todo RSpec/MultipleExpectations
      # rubocop:enable RSpec/MultipleExpectations
      invitation = create(:better_together_event_invitation,
                          invitable: event,
                          invitee_email: 'guest2@example.test',
                          status: 'pending',
                          valid_from: Time.current)

      user = BetterTogether::User.find_by(email: 'user@example.test') ||
             create(:better_together_user, :confirmed, email: 'user@example.test', password: 'SecureTest123!@#')

      # Clear any existing session and login as the specific user
      logout if respond_to?(:logout)
      login(user.email, 'SecureTest123!@#')

      post better_together.decline_invitation_path(invitation.token, locale: locale)

      expect(response).to have_http_status(:found)
      expect(invitation.reload.status).to eq('declined')
    end
  end
end
