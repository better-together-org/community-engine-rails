# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::CalendarsController', :as_user do
  let(:locale) { I18n.default_locale }

  it 'renders index' do
    get better_together.calendars_path(locale:)
    expect(response).to have_http_status(:ok)
  end

  context 'when viewing calendar show page' do
    let(:calendar) { create('better_together/calendar') }
    let(:upcoming_event) do
      BetterTogether::Event.create!(
        name: 'Upcoming',
        starts_at: 2.days.from_now,
        identifier: SecureRandom.uuid
      )
    end
    let(:past_event) do
      BetterTogether::Event.create!(
        name: 'Past',
        starts_at: 3.days.ago,
        identifier: SecureRandom.uuid
      )
    end

    before do
      BetterTogether::CalendarEntry.create!(calendar:, event: upcoming_event, starts_at: upcoming_event.starts_at)
      BetterTogether::CalendarEntry.create!(calendar:, event: past_event, starts_at: past_event.starts_at)
    end

    it 'renders successfully' do
      get better_together.calendar_path(calendar, locale:)

      expect(response).to have_http_status(:ok)
    end
  end
end
