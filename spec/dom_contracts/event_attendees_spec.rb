# frozen_string_literal: true

require 'rails_helper'

# DOM contract and block filtering for the event attendee list and RSVP counts.
# Identifiers are targeted by spec/docs_screenshots/better_together/event_attendees_block_filter_spec.rb.
RSpec.describe 'Event attendees DOM contract', :as_user, type: :request do # rubocop:disable RSpec/DescribeClass
  let(:platform) { BetterTogether::Platform.find_by(host: true) }
  let(:manager) { BetterTogether::User.find_by(email: 'user@example.test').person }
  let(:event) { create(:event, platform:, creator: manager, privacy: 'public') }
  let(:friend) { create(:person, name: 'Friendly Attendee') }
  let(:blocked) { create(:person, name: 'Blocked Attendee') }
  let(:blocker) { create(:person, name: 'Blocking Attendee') }

  before do
    create(:event_attendance, event:, person: friend, status: 'going')
    create(:event_attendance, event:, person: blocked, status: 'going')
    create(:event_attendance, event:, person: blocker, status: 'interested')
    create(:person_block, blocker: manager, blocked:)
    create(:person_block, blocker:, blocked: manager)
  end

  it 'exposes stable identifiers and lists only attendees without a block' do # rubocop:disable RSpec/MultipleExpectations
    get "/#{I18n.default_locale}/events/#{event.slug}"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="event-attendees-list"')
    expect(response.body).to include('id="event-attendees-heading"')
    expect(response.body).to include('id="event-rsvp-counts"')
    expect(response.body).to include(ActionView::RecordIdentifier.dom_id(event.event_attendances.find_by(person: friend)))
    expect_html_content('Friendly Attendee')
    expect_no_html_content('Blocked Attendee')
    expect_no_html_content('Blocking Attendee')
  end

  it 'counts only attendees without a block in the tab label and RSVP summary' do
    get "/#{I18n.default_locale}/events/#{event.slug}"

    expect(response.body).to include('Attendees (1)')
  end
end
