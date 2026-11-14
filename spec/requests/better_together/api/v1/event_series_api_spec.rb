# frozen_string_literal: true

require 'rails_helper'

# The ingester creates a series, creates sessions in it, and later groups an event it first saw as a single one.
RSpec.describe 'Event series API' do
  include RequestSpecHelper

  let(:headers) do
    api_auth_headers(BetterTogether::User.find_by!(email: 'manager@example.test'))
      .merge('Content-Type' => 'application/vnd.api+json', 'Accept' => 'application/vnd.api+json')
  end
  let(:starts) { 5.days.from_now.change(usec: 0) }

  before do
    configure_host_platform
    manager = BetterTogether::User.find_by!(email: 'manager@example.test').person
    BetterTogether::AgreementBuilder.build
    BetterTogether::Agreement.find_by!(identifier: 'content_publishing_agreement').agreement_participants
                             .create!(participant: manager, accepted_at: Time.zone.now, acceptance_method: 'system')
  end

  def create_event(attributes)
    body = { data: { type: 'events', attributes: } }
    post '/api/v1/events', params: body.to_json, headers: headers
    parsed = JSON.parse(response.body)
    parsed.dig('data', 'attributes') || parsed
  end

  def update_event(id, attributes)
    body = { data: { type: 'events', id:, attributes: } }
    patch "/api/v1/events/#{id}", params: body.to_json, headers: headers
  end

  def session_attributes(name, start)
    { name:, identifier: name.parameterize, starts_at: start.iso8601, ends_at: (start + 2.hours).iso8601,
      timezone: 'America/St_Johns', privacy: 'public', status: 'confirmed' }
  end

  def create_series
    create_event(name: 'Tribute Run', identifier: 'tribute-run', series: true, privacy: 'public',
                 timezone: 'America/St_Johns', status: 'confirmed')
  end

  def event_named(identifier)
    BetterTogether::Event.find_by!(identifier:)
  end

  it 'creates a series with no dates, then sessions in it', :aggregate_failures do
    series = create_series
    session = create_event(session_attributes('Tribute Night One', starts).merge(session_of: 'tribute-run'))

    expect([series['series'], session['series_identifier']]).to eq([true, 'tribute-run'])
    expect(event_named('tribute-run').starts_at).to eq(starts)
  end

  describe 'grouping an existing event' do
    before do
      create_series
      create_event(session_attributes('Tribute Night One', starts))
      update_event(event_named('tribute-night-one').id, session_of: 'tribute-run')
    end

    it 'links it to the series', :aggregate_failures do
      expect(response).to have_http_status(:ok)
      expect(event_named('tribute-night-one').parent_series.identifier).to eq('tribute-run')
    end

    it 'leaves its own fields alone' do
      expect(event_named('tribute-night-one').name).to eq('Tribute Night One')
    end
  end

  describe 'refusals' do
    before do
      create_series
      create_event(session_attributes('Night One', starts).merge(session_of: 'tribute-run'))
      create_event(session_attributes('Night Two', starts + 1.day))
    end

    it 'answers 422 for an event already in a series' do
      update_event(event_named('night-one').id, session_of: 'tribute-run')

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'answers 422 when the target is not a series' do
      update_event(event_named('night-two').id, session_of: 'night-one')

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'answers 422 when turning an existing event into a series' do
      update_event(event_named('night-two').id, series: true)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
