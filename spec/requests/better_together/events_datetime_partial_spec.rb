# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Events datetime fields partial', :as_platform_manager do
  let(:locale) { I18n.default_locale }

  describe 'form rendering' do
    # rubocop:todo RSpec/MultipleExpectations
    it 'renders the datetime fields partial correctly' do # rubocop:todo RSpec/ExampleLength, RSpec/MultipleExpectations
      # rubocop:enable RSpec/MultipleExpectations
      get better_together.new_event_path(locale: locale)

      expect(response.body).to include('data-controller="event-datetime"')
      expect(response.body).to include('data-event-datetime-target="startTime"')
      expect(response.body).to include('data-event-datetime-target="endTime"')
      expect(response.body).to include('data-event-datetime-target="duration"')
      expect(response.body).to include('data-action="change->event-datetime#updateEndTime"')
      expect(response.body).to include('data-action="change->event-datetime#updateDuration"')
      expect(response.body).to include('data-action="change->event-datetime#updateEndTimeFromDuration"')
    end

    it 'includes duration field with default value setup' do # rubocop:todo RSpec/MultipleExpectations
      get better_together.new_event_path(locale: locale)

      expect(response.body).to include('value="30"')
      expect(response.body).to include('step="5"')
      expect(response.body).to include('min="5"')
      expect(response.body).to include('minutes')
    end

    # rubocop:todo RSpec/MultipleExpectations
    it 'shows proper labels and hints' do # rubocop:todo RSpec/ExampleLength, RSpec/MultipleExpectations
      # rubocop:enable RSpec/MultipleExpectations
      get better_together.new_event_path(locale: locale)

      expect(response.body).to include(I18n.t('better_together.events.labels.starts_at'))
      expect(response.body).to include(I18n.t('better_together.events.labels.ends_at'))
      expect(response.body).to include(I18n.t('better_together.events.labels.duration_minutes'))
      expect(response.body).to include(I18n.t('better_together.events.hints.starts_at'))
      expect(response.body).to include(I18n.t('better_together.events.hints.ends_at'))
      expect(response.body).to include(I18n.t('better_together.events.hints.duration_minutes'))
    end
  end

  describe 'form submission with datetime fields' do
    # rubocop:todo RSpec/MultipleExpectations
    it 'processes form data correctly with partial' do # rubocop:todo RSpec/ExampleLength, RSpec/MultipleExpectations
      # rubocop:enable RSpec/MultipleExpectations
      event_params = {
        event: {
          title: 'Test Event with Datetime',
          description: 'Testing our new datetime partial',
          starts_at: 1.hour.from_now.strftime('%Y-%m-%dT%H:%M'),
          ends_at: 2.hours.from_now.strftime('%Y-%m-%dT%H:%M'),
          duration_minutes: '60',
          status: 'scheduled',
          privacy: 'public'
        },
        locale: locale
      }

      expect do
        post better_together.events_path, params: event_params
      end.to change(BetterTogether::Event, :count).by(1)

      event = BetterTogether::Event.last
      expect(event.title).to eq('Test Event with Datetime')
      expect(event.duration_minutes).to eq(60)
      expect(event.status).to eq('scheduled')
    end
  end
end
