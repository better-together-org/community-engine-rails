# frozen_string_literal: true

require 'rails_helper'

# A series groups sessions that are full events; its dates come from the sessions and cancelling or deleting it
# needs a choice for them.
RSpec.describe BetterTogether::EventSeries do
  include RequestSpecHelper

  let(:creator) { create(:better_together_person) }
  let(:series) { create(:better_together_event, series: true, starts_at: nil, ends_at: nil, creator:) }
  let(:first_start) { 3.days.from_now.change(usec: 0) }
  let(:second_start) { 4.days.from_now.change(usec: 0) }

  before { configure_host_platform }

  def add_session(start, **attrs)
    create(:better_together_event, starts_at: start, ends_at: start + 2.hours, creator:,
                                   session_of: series.identifier, **attrs)
  end

  describe 'linking' do
    it 'links a session to its series and keeps the series out of federation', :aggregate_failures do
      session = add_session(first_start)

      expect(session.reload.session?).to be(true)
      expect(session.parent_series).to eq(series)
      expect(series.reload.sessions).to contain_exactly(session)
      expect(series.federation_visibility).to eq('no_federate')
    end

    it 'rejects an identifier that is not a series' do
      event = build(:better_together_event, creator:, session_of: 'no-such-series')

      expect(event).not_to be_valid
    end

    it 'does not let a series be a session' do
      other = create(:better_together_event, series: true, starts_at: nil, ends_at: nil, creator:)
      link = BetterTogether::EventSeriesSession.new(series:, session: other)

      expect(link).not_to be_valid
    end

    it 'copies the series description onto a session that has none' do
      series.update!(description: 'About the run')

      expect(add_session(first_start, description: '').description.to_plain_text).to eq('About the run')
    end
  end

  describe 'grouping an existing event' do
    let(:standalone) do
      create(:better_together_event, starts_at: first_start, ends_at: first_start + 2.hours, creator:,
                                     description: 'Own text', privacy: 'public')
    end

    it 'links it and leaves its own fields alone', :aggregate_failures do
      series.update!(privacy: 'private', description: 'Series text')
      standalone.update!(session_of: series.identifier)

      expect(standalone.reload.parent_series).to eq(series)
      expect([standalone.privacy, standalone.description.to_plain_text]).to eq(['public', 'Own text'])
      expect(series.reload.starts_at).to eq(first_start)
    end

    it 'refuses an event that is already a session' do
      session = add_session(first_start)
      other = create(:better_together_event, series: true, starts_at: nil, ends_at: nil, creator:)

      session.update(session_of: other.identifier)

      expect(session.reload.parent_series).to eq(series)
    end

    it 'refuses a series, and changing whether an event is a series', :aggregate_failures do
      expect(series.update(session_of: series.identifier)).to be(false)
      expect(standalone.update(series: true)).to be(false)
      expect(series.update(series: false)).to be(false)
    end
  end

  describe 'dates' do
    before do
      add_session(first_start)
      add_session(second_start)
      add_session(second_start + 1.day, status: 'cancelled')
      series.reload
    end

    it 'spans the sessions, ignoring cancelled ones', :aggregate_failures do
      expect(series.starts_at).to be_within(1.second).of(first_start)
      expect(series.ends_at).to be_within(1.second).of(second_start + 2.hours)
      expect(series.next_occurrence_at).to be_within(1.second).of(first_start)
    end

    it 'follows a session when it moves' do
      series.sessions.min_by(&:starts_at).update!(starts_at: second_start - 1.hour, ends_at: second_start)

      expect(series.reload.starts_at).to be_within(1.second).of(second_start - 1.hour)
    end

    it 'cannot be authored by hand' do
      series.starts_at = 1.day.from_now

      expect(series).not_to be_valid
    end
  end

  describe 'cancelling' do
    let!(:upcoming) { add_session(first_start) }

    it 'needs a choice for the sessions' do
      series.status = 'cancelled'
      series.valid?

      expect(series.errors[:session_disposition]).to be_present
    end

    it 'cancels the upcoming sessions when asked' do
      series.cancel_series!(sessions: 'cancel')

      expect(upcoming.reload).to be_status_cancelled
    end

    it 'leaves past sessions alone' do
      past = add_session(2.days.ago)
      series.cancel_series!(sessions: 'cancel')

      expect(past.reload).not_to be_status_cancelled
    end

    it 'promotes the sessions to standalone events when asked', :aggregate_failures do
      series.cancel_series!(sessions: 'promote')

      expect(upcoming.reload).not_to be_status_cancelled
      expect(upcoming.session?).to be(false)
    end
  end

  describe 'deleting' do
    let!(:session) { add_session(first_start) }

    it 'needs a choice for the sessions', :aggregate_failures do
      expect(series.destroy).to be(false)
      expect(BetterTogether::Event.exists?(series.id)).to be(true)
    end

    it 'deletes the sessions when asked' do
      series.destroy_series!(sessions: 'delete')

      expect(BetterTogether::Event.exists?(session.id)).to be(false)
    end

    it 'promotes the sessions when asked', :aggregate_failures do
      series.destroy_series!(sessions: 'promote')

      expect(BetterTogether::Event.exists?(session.id)).to be(true)
      expect(session.reload.session?).to be(false)
    end
  end

  describe 'listing' do
    it 'shows sessions and leaves the series out' do
      session = add_session(first_start)
      found = BetterTogether::EventsSearchFilter.call(relation: BetterTogether::Event.all, params: {})

      expect(found.to_a & [series, session]).to eq([session])
    end
  end
end
