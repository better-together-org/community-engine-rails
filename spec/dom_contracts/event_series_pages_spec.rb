# frozen_string_literal: true

require 'rails_helper'

# Stable DOM ids that the event series screenshots and styles rely on.
RSpec.describe 'Event series DOM contract', type: :request do
  include RequestSpecHelper

  let(:locale) { I18n.default_locale }
  let(:series) do
    create(:better_together_event, series: true, starts_at: nil, ends_at: nil, privacy: 'public', name: 'Run')
  end
  let(:session) do
    create(:better_together_event, starts_at: 3.days.from_now, ends_at: 3.days.from_now + 1.hour, privacy: 'public',
                                   name: 'Night', session_of: series.identifier)
  end

  before do
    configure_host_platform
    session
    login('manager@example.test', 'SecureTest123!@#')
  end

  it 'gives the series page its sessions list and disposition panel', :aggregate_failures do
    get "/#{locale}/events/#{series.slug}"

    expect(response.body).to include("id=\"sessions_event_#{series.id}\"", "id=\"disposition_event_#{series.id}\"",
                                     "id=\"cancel_form_event_#{series.id}\"", "id=\"delete_form_event_#{series.id}\"")
  end

  it 'gives the session page its series banner', :aggregate_failures do
    get "/#{locale}/events/#{session.slug}"

    expect(response.body).to include("id=\"series_banner_event_#{session.id}\"", 'event-series-banner')
  end

  it 'gives the session card its series mention' do
    get "/#{locale}/events"

    expect(response.body).to include("id=\"series_mention_event_#{session.id}\"")
  end
end
