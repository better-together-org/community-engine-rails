# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Invitation Error Handling', :as_platform_manager do
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

  describe 'handling validation errors' do
    it 'returns error message for missing email' do
      post better_together.event_invitations_path(event_id: event.slug, locale: locale),
           params: { invitation: { invitee_email: '' } }

      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(better_together.event_path(event, locale: locale))
      follow_redirect!
      expect(flash[:alert]).to be_present
      expect(flash[:alert]).to match(/invitee.*must be present/i)
    end

    it 'handles turbo stream error responses' do
      post better_together.event_invitations_path(event_id: event.slug, locale: locale),
           params: { invitation: { invitee_email: '' } },
           headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.content_type).to include('text/vnd.turbo-stream.html')
      expect(response.body).to include('flash_messages')
    end
  end
end
