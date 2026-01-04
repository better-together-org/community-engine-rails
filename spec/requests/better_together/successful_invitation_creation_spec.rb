# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Successful Invitation Creation', :as_platform_manager do
  let(:locale) { I18n.default_locale }
  let!(:manager_user) { BetterTogether::User.find_by(email: 'manager@example.test') }
  let!(:event) do
    BetterTogether::Event.create!(
      name: 'Test Event',
      starts_at: 1.day.from_now,
      identifier: SecureRandom.uuid,
      privacy: 'public',
      creator: manager_user.person
    )
  end

  it 'creates a valid invitation successfully' do
    expect do
      post better_together.event_invitations_path(event_id: event.slug, locale: locale),
           params: { invitation: { invitee_email: 'valid@example.com' } }
    end.to change(BetterTogether::Invitation, :count).by(1)

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(better_together.event_path(event, locale: locale))

    # Check the invitation was created properly
    invitation = BetterTogether::Invitation.last
    expect(invitation.invitee_email).to eq('valid@example.com')
    expect(invitation.status).to eq('pending')
    expect(invitation.valid_from).to be_present
    expect(invitation.locale).to eq('en')
  end
end
