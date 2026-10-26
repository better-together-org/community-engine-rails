# frozen_string_literal: true

require 'rails_helper'

# The events list and a community's events show the sessions of a series, not the series itself, which keeps a page
# of its own.
RSpec.describe 'Event series in lists' do
  include RequestSpecHelper

  let(:locale) { I18n.default_locale }
  let(:community) { create(:better_together_community, privacy: 'public') }
  let(:series) do
    create(:better_together_event, series: true, starts_at: nil, ends_at: nil, privacy: 'public', name: 'Tribute Run')
  end
  let(:session) do
    create(:better_together_event, starts_at: 3.days.from_now, ends_at: 3.days.from_now + 2.hours, privacy: 'public',
                                   name: 'Tribute Night', session_of: series.identifier)
  end

  # The series is not listed; its sessions are.
  def series_links
    Nokogiri::HTML(response.body).css(%(a[href*="events/#{series.slug}"]))
  end

  before do
    configure_host_platform
    BetterTogether::EventHost.create!(event: session, host: community)
  end

  it 'lists the session and not the series to an anonymous visitor', :aggregate_failures do
    get "/#{locale}/events"

    expect(response.body).to include(session.slug)
    expect(series_links).to be_empty
  end

  it 'lists the session and not the series in the hosting community events tab', :aggregate_failures do
    BetterTogether::EventHost.create!(event: series, host: community)
    get "/#{locale}/events", params: { community_id: community.slug }

    expect(response.body).to include("events/#{session.slug}")
    expect(series_links).to be_empty
  end

  it 'still shows the series on its own page' do
    get "/#{locale}/events/#{series.slug}"

    expect(response).to have_http_status(:ok)
  end
end
