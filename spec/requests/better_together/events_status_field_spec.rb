# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Event form status field', :as_platform_manager do
  let(:manager_person) { BetterTogether::User.find_by(email: 'manager@example.test').person }
  let(:platform) { BetterTogether::Platform.find_by(host: true) }

  before do
    grant_content_publishing_agreement(manager_person)
  end

  it 'renders the status select with all statuses on the new event form' do # rubocop:disable RSpec/MultipleExpectations
    get "/#{I18n.default_locale}/events/new"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="event-status-field"')
    expect(response.body).to include('name="event[status]"')
    BetterTogether::Event.statuses.each_value do |value|
      expect(response.body).to include(%(value="#{value}"))
    end
  end

  it 'renders the persisted status as selected on the edit form' do
    event = create(:event, platform:, creator: manager_person, status: 'draft')

    get "/#{I18n.default_locale}/events/#{event.slug}/edit"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('<option selected="selected" value="draft"')
  end

  it 'updates the status through the form params (draft -> confirmed publishes the event)' do
    event = create(:event, platform:, creator: manager_person, status: 'draft')

    patch "/#{I18n.default_locale}/events/#{event.slug}", params: { event: { status: 'confirmed' } }

    expect(event.reload.status).to eq('confirmed')
  end

  it 'creates events with an explicitly chosen status' do # rubocop:disable RSpec/MultipleExpectations
    starts_at = 2.weeks.from_now

    expect do
      post "/#{I18n.default_locale}/events", params: {
        event: {
          name: 'Status Field Creation Test',
          status: 'confirmed',
          starts_at: starts_at.iso8601,
          ends_at: (starts_at + 2.hours).iso8601,
          identifier: SecureRandom.uuid,
          timezone: 'UTC',
          event_hosts_attributes: [{ host_type: 'BetterTogether::Person', host_id: manager_person.id }]
        }
      }
    end.to change(BetterTogether::Event, :count).by(1)

    expect(BetterTogether::Event.order(:created_at).last.status).to eq('confirmed')
  end
end
