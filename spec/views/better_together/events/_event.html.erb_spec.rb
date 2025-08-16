# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/events/_event', type: :view do
  it 'renders formatted location and time range' do
    start_time = Time.zone.parse('2024-03-10 15:00')
    end_time = Time.zone.parse('2024-03-10 17:00')
    locatable = instance_double(
      BetterTogether::Geography::LocatableLocation,
      name: 'Town Hall',
      location: 'Springfield'
    )
    event = instance_double(
      BetterTogether::Event,
      cache_key_with_version: 'events/1-20240310',
      starts_at: start_time,
      ends_at: end_time,
      location: locatable
    )

    view.define_singleton_method(:categories_badge) { |*_args| '' }
    allow(view).to receive(:render).with('better_together/shared/card', entity: event).and_yield
    allow(view).to receive(:event_time_range).and_call_original
    allow(view).to receive(:event_location).and_call_original

    render partial: 'better_together/events/event', locals: { event: event }

    expect(view).to have_received(:event_time_range).with(event, format: :short)
    expect(view).to have_received(:event_location).with(event)

    expect(rendered).to include('Town Hall, Springfield')
    expected_time = "#{I18n.l(start_time, format: :event)} - #{I18n.l(end_time, format: '%-I:%M %p')}"
    expect(rendered).to include(expected_time)
  end
end
