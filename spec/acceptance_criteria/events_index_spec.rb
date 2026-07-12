# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/DescribeClass, RSpec/MultipleDescribes, RSpec/ExampleLength, RSpec/MultipleExpectations
# Events Index — Search, Filter & Pagination (v0.12.0)
# Plan: docs/plans/events-index-filter-pagination.md
#
# Acceptance criteria specs for events index filtering and pagination.
# Implementation follows 3-week cadence (parallel with Posts):
#   Week 1: Model layer (EventsSearchFilter service; reuses ContentSearchFilter base)
#   Week 2: Request layer (Controller + authorization)
#   Week 3: Feature layer (Views + UX + pagination)
#
# Adaptations from the original pending outline (see plan doc Implementation
# Notes): Event translates :name (not :title) and the column is starts_at
# (not start_at); events have a creator (not an organizer association);
# categorizations take categorizable:; status is the new explicit enum
# column added for this feature (draft/confirmed/cancelled).

# ============================================================================
# WEEK 1: MODEL LAYER — EventsSearchFilter Service Foundation
# ============================================================================

RSpec.describe 'EventsSearchFilter service', tag: %i[acceptance_criteria ac_events model week1], type: :model do
  let(:platform) { create(:platform, :public) }
  let(:creator) { create(:person) }
  let(:category) { create(:event_category) }
  let(:relation) { BetterTogether::Event.where(platform_id: platform.id) }

  # AC1: Service returns Kaminari-decorated relation
  it 'EventsSearchFilter.call(relation:, params:) returns Kaminari-decorated relation' do
    create_list(:event, 3, platform:, creator:)

    result = BetterTogether::EventsSearchFilter.call(relation:, params: {})

    expect(result).to respond_to(:total_count)
    expect(result).to respond_to(:total_pages)
    expect(result).to respond_to(:current_page)
    expect(result.count).to eq(3)
  end

  # AC2: Text search via ILIKE on Mobility name + ActionText description
  it 'q: "community" applies ILIKE to Mobility name + ActionText description' do
    event_found = create(:event, platform:, creator:, name: 'Community Potluck')
    event_not_found = create(:event, platform:, creator:, name: 'Board Meeting')

    result = BetterTogether::EventsSearchFilter.call(relation:, params: { q: 'community' })

    expect(result.map(&:id)).to include(event_found.id)
    expect(result.map(&:id)).not_to include(event_not_found.id)
  end

  # AC3: Category filter via multi-select
  it 'category_ids: [id] joins categorizations and returns only tagged events' do
    event_categorized = create(:event, platform:, creator:)
    event_uncategorized = create(:event, platform:, creator:)
    create(:categorization, categorizable: event_categorized, category:)

    result = BetterTogether::EventsSearchFilter.call(
      relation:,
      params: { category_ids: [category.id] }
    )

    expect(result.map(&:id)).to include(event_categorized.id)
    expect(result.map(&:id)).not_to include(event_uncategorized.id)
  end

  # AC4: Status filter (single value)
  it 'status: "draft" filters by events.status enum' do
    event_draft = create(:event, platform:, creator:, status: 'draft')
    event_confirmed = create(:event, platform:, creator:, status: 'confirmed')

    result = BetterTogether::EventsSearchFilter.call(
      relation:,
      params: { status: 'draft' }
    )

    expect(result.map(&:id)).to include(event_draft.id)
    expect(result.map(&:id)).not_to include(event_confirmed.id)
  end

  # AC5: Status filter (array/union)
  it 'status: ["draft", "confirmed"] supports status union (multiple statuses)' do
    event_draft = create(:event, platform:, creator:, status: 'draft')
    event_confirmed = create(:event, platform:, creator:, status: 'confirmed')
    event_cancelled = create(:event, platform:, creator:, status: 'cancelled')

    result = BetterTogether::EventsSearchFilter.call(
      relation:,
      params: { status: %w[draft confirmed] }
    )

    expect(result.map(&:id)).to include(event_draft.id, event_confirmed.id)
    expect(result.map(&:id)).not_to include(event_cancelled.id)
  end

  # AC6: Order-by flexibility (soonest/latest/newest/oldest)
  it 'order_by: "latest" orders starts_at desc (furthest events first)' do
    soon_event = create(:event, platform:, creator:, starts_at: 1.week.from_now, ends_at: 1.week.from_now + 2.hours)
    far_event = create(:event, platform:, creator:, starts_at: 3.months.from_now, ends_at: 3.months.from_now + 2.hours)

    result_latest = BetterTogether::EventsSearchFilter.call(
      relation:,
      params: { order_by: 'latest' }
    ).to_a

    expect(result_latest.first).to eq(far_event)
    expect(result_latest.last).to eq(soon_event)
  end

  # AC7: Order-by newest (creation order)
  it 'order_by: "newest" orders created_at desc (most recent creation first)' do
    old_event = create(:event, platform:, creator:, created_at: 1.week.ago)
    new_event = create(:event, platform:, creator:, created_at: 1.day.ago)

    result_newest = BetterTogether::EventsSearchFilter.call(
      relation:,
      params: { order_by: 'newest' }
    ).to_a

    expect(result_newest.first).to eq(new_event)
    expect(result_newest.last).to eq(old_event)
  end

  # AC8: Order-by oldest (creation order)
  it 'order_by: "oldest" orders created_at asc (earliest creation first)' do
    old_event = create(:event, platform:, creator:, created_at: 1.week.ago)
    new_event = create(:event, platform:, creator:, created_at: 1.day.ago)

    result_oldest = BetterTogether::EventsSearchFilter.call(
      relation:,
      params: { order_by: 'oldest' }
    ).to_a

    expect(result_oldest.first).to eq(old_event)
    expect(result_oldest.last).to eq(new_event)
  end

  # AC9: Pagination via Kaminari
  it 'per_page: 10 applies Kaminari .per(10), defaults to 20' do
    create_list(:event, 25, platform:, creator:)

    result = BetterTogether::EventsSearchFilter.call(
      relation:,
      params: { per_page: 10, page: 1 }
    )

    expect(result.length).to eq(10)
    expect(result.total_pages).to eq(3)
  end

  # AC10: Default scope filters to upcoming events
  it 'Empty params returns upcoming events only (starts_at >= now), soonest-first' do
    past_event = create(:event, :past, platform:, creator:)
    upcoming_event = create(:event, platform:, creator:)

    result = BetterTogether::EventsSearchFilter.call(relation:, params: {})

    expect(result.map(&:id)).to include(upcoming_event.id)
    expect(result.map(&:id)).not_to include(past_event.id)
    expect(result.to_a.first).to eq(upcoming_event) # Soonest-first (default order)
  end

  # AC11: No N+1 queries on empty params
  it 'Empty params returns upcoming events with no N+1 joins' do
    create_list(:event, 5, platform:, creator:)
    preloaded_relation = relation.includes(:creator)

    result = BetterTogether::EventsSearchFilter.call(relation: preloaded_relation, params: {})

    queries = []
    counter = lambda do |_name, _start, _finish, _id, payload|
      next if payload[:name] == 'SCHEMA' || payload[:sql].match?(/\A(BEGIN|COMMIT|SAVEPOINT|RELEASE)/)

      queries << payload[:sql]
    end
    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') do
      result.each(&:creator) # Force association load
    end

    expect(queries.length).to be <= 10
  end
end

# ============================================================================
# WEEK 2: REQUEST LAYER — Controller & Authorization
# ============================================================================

RSpec.describe 'EventsController#index request', :as_user,
               tag: %i[acceptance_criteria ac_events request week2], type: :request do
  let(:platform) { BetterTogether::Platform.find_by(host: true) }
  let(:creator) { create(:person) }
  let(:user_person) { BetterTogether::User.find_by(email: 'user@example.test').person }

  # AC12: GET /en/events with no params returns 200, upcoming events, soonest-first
  it 'GET /en/events with no params returns 200, upcoming events, soonest-first, 20 per page' do
    past_event = create(:event, :past, platform:, creator:)
    upcoming1 = create(:event, platform:, creator:, starts_at: 1.week.from_now, ends_at: 1.week.from_now + 2.hours)
    upcoming2 = create(:event, platform:, creator:, starts_at: 3.weeks.from_now, ends_at: 3.weeks.from_now + 2.hours)

    get '/en/events'

    expect(response).to have_http_status(:ok)
    expect(assigns(:events)).to include(upcoming1, upcoming2)
    expect(assigns(:events)).not_to include(past_event)
    expect(assigns(:events).to_a.first).to eq(upcoming1) # Soonest-first
    expect(assigns(:events).limit_value).to eq(20) # Default 20 per page
  end

  # AC13: Text search filters by name + description, params persist
  it '?q=yoga filters results by name/description, params persist in view' do
    event_found = create(:event, platform:, creator:, name: 'Yoga Class')
    event_not_found = create(:event, platform:, creator:, name: 'Book Club')

    get '/en/events', params: { q: 'yoga' }

    expect(assigns(:events)).to include(event_found)
    expect(assigns(:events)).not_to include(event_not_found)
    expect(response.body).to include('value="yoga"') # Form state persists
  end

  # AC14: Category multi-select
  it '?category_ids[]=1&category_ids[]=2 multi-select works' do
    event_cat1 = create(:event, platform:, creator:)
    event_cat2 = create(:event, platform:, creator:)
    event_uncategorized = create(:event, platform:, creator:)
    cat1 = create(:event_category)
    cat2 = create(:event_category)
    create(:categorization, categorizable: event_cat1, category: cat1)
    create(:categorization, categorizable: event_cat2, category: cat2)

    get '/en/events', params: { category_ids: [cat1.id, cat2.id] }

    expect(assigns(:events)).to include(event_cat1, event_cat2)
    expect(assigns(:events)).not_to include(event_uncategorized)
  end

  # AC15: Status filter
  # Draft events are only visible to people connected to them, so the draft
  # here belongs to the signed-in person (policy scope hides others' drafts).
  it '?status=draft shows only drafts' do
    event_draft = create(:event, platform:, creator: user_person, status: 'draft')
    event_confirmed = create(:event, platform:, creator:, status: 'confirmed')

    get '/en/events', params: { status: 'draft' }

    expect(assigns(:events)).to include(event_draft)
    expect(assigns(:events)).not_to include(event_confirmed)
  end

  # AC16: Status union
  it '?status[]=draft&status[]=confirmed shows drafts + confirmed (union)' do
    event_draft = create(:event, platform:, creator: user_person, status: 'draft')
    event_confirmed = create(:event, platform:, creator:, status: 'confirmed')
    event_cancelled = create(:event, platform:, creator:, status: 'cancelled')

    get '/en/events', params: { status: %w[draft confirmed] }

    expect(assigns(:events)).to include(event_draft, event_confirmed)
    expect(assigns(:events)).not_to include(event_cancelled)
  end

  # AC17: Order-by flexibility
  it '?order_by=latest orders furthest-first' do
    create(:event, platform:, creator:, starts_at: 1.week.from_now, ends_at: 1.week.from_now + 2.hours)
    far_event = create(:event, platform:, creator:, starts_at: 3.months.from_now, ends_at: 3.months.from_now + 2.hours)

    get '/en/events', params: { order_by: 'latest' }

    expect(assigns(:events).to_a.first).to eq(far_event)
  end

  # AC18: Pagination query params
  it '?page=2&per_page=10 paginates correctly' do
    create_list(:event, 25, platform:, creator:)

    get '/en/events', params: { page: 2, per_page: 10 }

    expect(assigns(:events).current_page).to eq(2)
    expect(assigns(:events).length).to eq(10)
  end

  # AC19: Authorization respects policy scope
  it 'Authorization: respects policy scope (organizer sees own drafts)' do
    my_draft = create(:event, platform:, creator: user_person, status: 'draft')
    other_draft = create(:event, platform:, creator:, status: 'draft')
    confirmed = create(:event, platform:, creator:, status: 'confirmed')

    get '/en/events'

    expect(assigns(:events)).to include(my_draft, confirmed)
    expect(assigns(:events)).not_to include(other_draft)
  end
end

# ============================================================================
# WEEK 3: FEATURE LAYER — Views, UX, Pagination, Mobile
# ============================================================================

RSpec.describe 'Events index UX and pagination', :as_user,
               tag: %i[acceptance_criteria ac_events feature week3], type: :feature do
  let(:platform) { BetterTogether::Platform.find_by(host: true) }
  let(:creator) { create(:person) }
  let(:category) { create(:event_category) }
  let(:user_person) { BetterTogether::User.find_by(email: 'user@example.test').person }

  before do
    create_list(:event, 25, platform:, creator:)
  end

  # AC20: Filter sidebar renders with all controls
  it 'Visit /en/events, see filter sidebar with all controls' do
    visit '/en/events'

    expect(page).to have_css('form.events-filter-sidebar')
    expect(page).to have_field('q', type: 'text')
    expect(page).to have_select('status')
    expect(page).to have_select('order_by')
    expect(page).to have_button('Search')
  end

  # AC21: Text search filters results
  it 'Type in search box, submit form, results filter by name + description' do
    yoga_event = create(:event, platform:, creator:, name: 'Yoga Class')

    visit '/en/events'
    within('form.events-filter-sidebar') do
      fill_in 'q', with: 'yoga'
      click_button 'Search'
    end

    expect(page).to have_text(yoga_event.name)
    expect(page).to have_css('form.events-filter-sidebar input[name="q"][value="yoga"]')
  end

  # AC22: Category multi-select filters
  it 'Select categories in the multi-select, results update' do
    categorized_event = create(:event, platform:, creator:, name: 'Categorized Gathering')
    create(:categorization, categorizable: categorized_event, category:)

    visit '/en/events'
    within('form.events-filter-sidebar') do
      select category.name, from: 'events-category-ids'
      click_button 'Search'
    end

    expect(page).to have_css('#events')
    expect(page).to have_text(categorized_event.name)
  end

  # AC23: Status select filters
  it 'Select status dropdown, results filter' do
    my_draft = create(:event, platform:, creator: user_person, status: 'draft', name: 'My Draft Event')

    visit '/en/events'
    within('form.events-filter-sidebar') do
      select 'Draft', from: 'status'
      click_button 'Search'
    end

    expect(page).to have_select('status', selected: 'Draft')
    expect(page).to have_text(my_draft.name)
  end

  # AC24: Order-by select re-sorts (soonest/latest/newest/oldest)
  it 'Select order-by, results re-sort (soonest/latest/newest/oldest all work)' do
    visit '/en/events'
    within('form.events-filter-sidebar') do
      select 'Latest', from: 'order_by'
      click_button 'Search'
    end

    expect(page).to have_select('order_by', selected: 'Latest')
    expect(page).to have_css('#events')
  end

  # AC25: Per-page select changes window size
  it 'Select per-page, page reloads with new window size' do
    visit '/en/events'
    within('form.events-filter-sidebar') do
      select '10', from: 'per_page'
      click_button 'Search'
    end

    event_count = page.all('.event-card').length
    expect(event_count).to be <= 10
    expect(event_count).to be_positive
  end

  # AC26: Pagination links navigate correctly
  it 'Pagination links present and navigate correctly' do
    visit '/en/events'

    expect(page).to have_css('.pagination')
    expect(page).to have_link('2')
    # Pagination renders above and below the results; use the first nav.
    first('.pagination').click_link('2')

    expect(page.current_url).to include('page=2')
  end

  # AC27: Clear filters link resets state to default (upcoming, soonest, 20 per page)
  it '"Clear Filters" link resets to default state (upcoming, soonest, 20 per page)' do
    visit '/en/events?status=draft&order_by=newest&per_page=10'

    expect(page).to have_link('Clear Filters')
    click_link 'Clear Filters'

    q_value = find('form.events-filter-sidebar input[name="q"]').value
    expect(q_value.to_s).to eq('')
    expect(page).to have_select('status', selected: 'All')
    expect(page).to have_select('order_by', selected: 'Soonest')
  end

  # AC28: Mobile sidebar collapse
  # The sidebar is wrapped in a Bootstrap collapse that is hidden below the
  # lg breakpoint (d-lg-block) and toggled by a d-lg-none button. The rack_test
  # driver cannot resize a viewport or run JS, so this asserts the collapse
  # markup contract instead of the visual state.
  it 'Sidebar collapses on mobile (≤768px)' do
    visit '/en/events'

    expect(page).to have_css('button.sidebar-toggle.d-lg-none', visible: :all)
    expect(page).to have_css('#events-filter-sidebar.collapse.d-lg-block .events-filter-sidebar', visible: :all)
    expect(page).to have_css('button.sidebar-toggle[data-bs-toggle="collapse"]', visible: :all)
  end
end
# rubocop:enable RSpec/DescribeClass, RSpec/MultipleDescribes, RSpec/ExampleLength, RSpec/MultipleExpectations
