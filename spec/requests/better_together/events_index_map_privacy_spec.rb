# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Events index map privacy', :no_auth do
  let(:locale) { I18n.default_locale }

  def geocode!(event, latitude:, longitude:)
    create(:geography_geospatial_space, geospatial: event.location.location,
                                        space: create(:geography_space, latitude:, longitude:))
  end

  it 'does not put an event the viewer cannot see on the map', :aggregate_failures do
    hidden = create(:event, :with_address_location, name: 'Hidden Private Gathering', privacy: 'private',
                                                    starts_at: 2.days.from_now, ends_at: 2.days.from_now + 2.hours)
    geocode!(hidden, latitude: 48.95, longitude: -57.95)

    get better_together.events_path(locale:)

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('Hidden Private Gathering')
    expect(response.body).not_to include('48.95')
  end

  it 'still maps a public event', :aggregate_failures do
    shown = create(:event, :with_address_location, name: 'Open Public Gathering', privacy: 'public',
                                                   starts_at: 2.days.from_now, ends_at: 2.days.from_now + 2.hours)
    geocode!(shown, latitude: 48.96, longitude: -57.96)

    get better_together.events_path(locale:)

    expect(response.body).to include('data-controller="better_together--map"')
    expect(response.body).to include('48.96')
  end
end
