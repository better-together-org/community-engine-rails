# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the events index: asserts the stable identifiers that
# documentation screenshots (spec/docs_screenshots/better_together/
# events_index_filter_spec.rb) and downstream tooling target. Runs in
# normal CI (no RUN_DOCS_SCREENSHOTS gate).
RSpec.describe 'Events index DOM contract', :as_platform_manager, type: :request do # rubocop:disable RSpec/DescribeClass
  let(:platform) { BetterTogether::Platform.find_by(host: true) }
  let(:creator) { create(:person) }

  before do
    category = create(:event_category)
    event = create(:event, platform:, creator:)
    create(:categorization, categorizable: event, category:)
    create_list(:event, 21, platform:, creator:)
  end

  it 'exposes the stable identifiers the docs screenshots target' do # rubocop:disable RSpec/MultipleExpectations, RSpec/ExampleLength
    get "/#{I18n.default_locale}/events"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="new-event-btn"')
    expect(response.body).to include('id="events-filter-toggle"')
    expect(response.body).to include('id="events-filter-sidebar"')
    expect(response.body).to include('class="events-filter-sidebar"')
    expect(response.body).to include('id="events-q"')
    expect(response.body).to include('id="events-category-ids"')
    expect(response.body).to include('id="events-status"')
    expect(response.body).to include('id="events-order-by"')
    expect(response.body).to include('id="events-per-page"')
    expect(response.body).to include('id="events-past"')
    expect(response.body).to include('id="events-search-submit"')
    expect(response.body).to include('id="events-result-count"')
    expect(response.body).to include('id="events-pagination"')
    expect(response.body).to include('id="events"')
    expect(response.body).to include('event-card')
  end

  it 'exposes the clear-filters link and status badge when filtering' do
    create(:event, platform:, creator: BetterTogether::User.find_by(email: 'manager@example.test').person,
                   status: 'draft')

    get "/#{I18n.default_locale}/events", params: { status: 'draft' }

    expect(response.body).to include('id="events-clear-filters"')
    expect(response.body).to include('event-status-badge')
  end
end
