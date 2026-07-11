# frozen_string_literal: true

# rubocop:disable RSpec/PendingWithoutReason, RSpec/DescribeClass
# Events Index — Search, Filter & Pagination (v0.12.0)
# Plan: docs/plans/events-index-filter-pagination.md
#
# This spec outlines acceptance criteria for events index filtering and pagination.
# All specs are pending until implementation week. Run with:
#   rspec spec/acceptance_criteria/events_index_spec.rb --tag acceptance_criteria --pending
#
# Implementation follows 3-week cadence (parallel with Posts):
#   Week 1: Model layer (EventsSearchFilter service; reuses ContentSearchFilter base)
#   Week 2: Request layer (Controller + authorization)
#   Week 3: Feature layer (Views + UX + pagination)

RSpec.describe 'Events Index — Search, Filter & Pagination (v0.12.0)' do
  # ============================================================================
  # WEEK 1: MODEL LAYER — EventsSearchFilter Service Foundation
  # ============================================================================

  describe 'EventsSearchFilter service', tag: %i[acceptance_criteria ac_events model week1] do
    let(:platform) { create(:platform) }
    let(:organizer) { create(:person, platform:) }
    let(:category) { create(:category, platform:) }

    # AC1: Service returns Kaminari-decorated relation
    skip 'EventsSearchFilter.call(relation:, params:) returns Kaminari-decorated relation' do
      create_list(:event, 3, platform:, organizer:)
      relation = platform.events

      result = BetterTogether::EventsSearchFilter.call(relation:, params: {})

      expect(result).to respond_to(:total_count)
      expect(result).to respond_to(:total_pages)
      expect(result).to respond_to(:current_page)
      skip 'Test structure: create events, call filter, verify pagination methods present'
    end

    # AC2: Text search via ILIKE on Mobility title + ActionText description
    skip 'q: "community" applies ILIKE to Mobility title + ActionText description' do
      event_found = create(:event, platform:, organizer:, title: 'Community Potluck', start_at: 1.week.from_now)
      event_not_found = create(:event, platform:, organizer:, title: 'Board Meeting', start_at: 1.week.from_now)
      relation = platform.events

      result = BetterTogether::EventsSearchFilter.call(relation:, params: { q: 'community' })

      expect(result).to include(event_found)
      expect(result).not_to include(event_not_found)
      skip 'Implementation: Mobility title join + ActionText description join with ILIKE "%community%"'
    end

    # AC3: Category filter via multi-select
    skip 'category_ids: [id] joins categorizations and returns only tagged events' do
      event_categorized = create(:event, platform:, organizer:, start_at: 1.week.from_now)
      event_uncategorized = create(:event, platform:, organizer:, start_at: 1.week.from_now)
      create(:categorization, event: event_categorized, category:)
      relation = platform.events

      result = BetterTogether::EventsSearchFilter.call(
        relation:,
        params: { category_ids: [category.id] }
      )

      expect(result).to include(event_categorized)
      expect(result).not_to include(event_uncategorized)
      skip 'Implementation: join better_together_categorizations, filter by category_ids (inherited from base)'
    end

    # AC4: Status filter (single value)
    skip 'status: "draft" filters by events.status enum' do
      event_draft = create(:event, platform:, organizer:, status: :draft, start_at: 1.week.from_now)
      event_confirmed = create(:event, platform:, organizer:, status: :confirmed, start_at: 1.week.from_now)
      relation = platform.events

      result = BetterTogether::EventsSearchFilter.call(
        relation:,
        params: { status: 'draft' }
      )

      expect(result).to include(event_draft)
      expect(result).not_to include(event_confirmed)
      skip 'Implementation: filter where status = "draft"'
    end

    # AC5: Status filter (array/union)
    skip 'status: ["draft", "confirmed"] supports status union (multiple statuses)' do
      event_draft = create(:event, platform:, organizer:, status: :draft, start_at: 1.week.from_now)
      event_confirmed = create(:event, platform:, organizer:, status: :confirmed, start_at: 1.week.from_now)
      event_cancelled = create(:event, platform:, organizer:, status: :cancelled, start_at: 1.week.from_now)
      relation = platform.events

      result = BetterTogether::EventsSearchFilter.call(
        relation:,
        params: { status: %w[draft confirmed] }
      )

      expect(result).to include(event_draft, event_confirmed)
      expect(result).not_to include(event_cancelled)
      skip 'Implementation: filter where status IN ("draft", "confirmed")'
    end

    # AC6: Order-by flexibility (soonest/latest/newest/oldest)
    skip 'order_by: "latest" orders start_at desc (furthest events first)' do
      soon_event = create(:event, platform:, organizer:, start_at: 1.week.from_now)
      far_event = create(:event, platform:, organizer:, start_at: 3.months.from_now)
      relation = platform.events

      result_latest = BetterTogether::EventsSearchFilter.call(
        relation:,
        params: { order_by: 'latest' }
      ).to_a

      expect(result_latest.first).to eq(far_event)
      expect(result_latest.last).to eq(soon_event)
      skip 'Implementation: latest → start_at desc; soonest → start_at asc (default)'
    end

    # AC7: Order-by newest (creation order)
    skip 'order_by: "newest" orders created_at desc (most recent creation first)' do
      old_event = create(:event, platform:, organizer:, created_at: 1.week.ago, start_at: 3.months.from_now)
      new_event = create(:event, platform:, organizer:, created_at: 1.day.ago, start_at: 3.months.from_now)
      relation = platform.events

      result_newest = BetterTogether::EventsSearchFilter.call(
        relation:,
        params: { order_by: 'newest' }
      ).to_a

      expect(result_newest.first).to eq(new_event)
      expect(result_newest.last).to eq(old_event)
      skip 'Implementation: newest → created_at desc'
    end

    # AC8: Order-by oldest (creation order)
    skip 'order_by: "oldest" orders created_at asc (earliest creation first)' do
      old_event = create(:event, platform:, organizer:, created_at: 1.week.ago, start_at: 3.months.from_now)
      new_event = create(:event, platform:, organizer:, created_at: 1.day.ago, start_at: 3.months.from_now)
      relation = platform.events

      result_oldest = BetterTogether::EventsSearchFilter.call(
        relation:,
        params: { order_by: 'oldest' }
      ).to_a

      expect(result_oldest.first).to eq(old_event)
      expect(result_oldest.last).to eq(new_event)
      skip 'Implementation: oldest → created_at asc'
    end

    # AC9: Pagination via Kaminari
    skip 'per_page: 10 applies Kaminari .per(10), defaults to 20' do
      create_list(:event, 25, platform:, organizer:, start_at: 1.week.from_now)
      relation = platform.events

      result = BetterTogether::EventsSearchFilter.call(
        relation:,
        params: { per_page: 10, page: 1 }
      )

      expect(result.length).to eq(10)
      expect(result.total_pages).to eq(3)
      skip 'Implementation: .page(params[:page]).per(params[:per_page] || 20) (inherited from base)'
    end

    # AC10: Default scope filters to upcoming events
    skip 'Empty params returns upcoming events only (start_at >= now), soonest-first' do
      past_event = create(:event, platform:, organizer:, start_at: 1.week.ago)
      upcoming_event = create(:event, platform:, organizer:, start_at: 1.week.from_now)
      relation = platform.events

      result = BetterTogether::EventsSearchFilter.call(relation:, params: {})

      expect(result).to include(upcoming_event)
      expect(result).not_to include(past_event)
      expect(result.to_a.first).to eq(upcoming_event) # Soonest-first (default order)
      skip 'Implementation: Default scope filter start_at >= Time.current; order soonest (start_at asc)'
    end

    # AC11: No N+1 queries on empty params
    skip 'Empty params returns upcoming events with no N+1 joins' do
      create_list(:event, 5, platform:, organizer:, start_at: 1.week.from_now)
      relation = platform.events

      expect do
        result = BetterTogether::EventsSearchFilter.call(relation:, params: {})
        result.each(&:organizer) # Force association load
      end.not_to exceed_query_limit(10)

      skip 'Implementation: Pre-load associations; verify no extra queries'
    end
  end

  # ============================================================================
  # WEEK 2: REQUEST LAYER — Controller & Authorization
  # ============================================================================

  describe 'EventsController#index request', tag: %i[acceptance_criteria ac_events request week2] do
    let(:platform) { create(:platform) }
    let(:user) { create(:person, platform:) }
    let(:organizer) { create(:person, platform:) }
    let(:category) { create(:category, platform:) }

    before { sign_in user }

    # AC12: GET /en/events with no params returns 200, upcoming events, soonest-first
    skip 'GET /en/events with no params returns 200, upcoming events, soonest-first, 20 per page' do
      past_event = create(:event, platform:, organizer:, start_at: 1.week.ago)
      upcoming1 = create(:event, platform:, organizer:, start_at: 1.week.from_now)
      upcoming2 = create(:event, platform:, organizer:, start_at: 3.weeks.from_now)

      get '/en/events'

      expect(response).to have_http_status(:ok)
      expect(assigns(:events)).to include(upcoming1, upcoming2)
      expect(assigns(:events)).not_to include(past_event)
      expect(assigns(:events).to_a.first).to eq(upcoming1) # Soonest-first
      skip 'Implementation: Apply EventsSearchFilter with default params'
    end

    # AC13: Text search filters by title + description, params persist
    skip '?q=yoga filters results by title/description, params persist in view' do
      event_found = create(:event, platform:, organizer:, title: 'Yoga Class', start_at: 1.week.from_now)
      event_not_found = create(:event, platform:, organizer:, title: 'Book Club', start_at: 1.week.from_now)

      get '/en/events', params: { q: 'yoga' }

      expect(assigns(:events)).to include(event_found)
      expect(assigns(:events)).not_to include(event_not_found)
      expect(response.body).to include('value="yoga"') # Form state persists
      skip 'Implementation: Pass filter_params to view; render form with current values'
    end

    # AC14: Category multi-select
    skip '?category_ids[]=1&category_ids[]=2 multi-select works' do
      event_cat1 = create(:event, platform:, organizer:, start_at: 1.week.from_now)
      event_cat2 = create(:event, platform:, organizer:, start_at: 1.week.from_now)
      cat1 = create(:category, platform:)
      cat2 = create(:category, platform:)
      create(:categorization, event: event_cat1, category: cat1)
      create(:categorization, event: event_cat2, category: cat2)

      get '/en/events', params: { category_ids: [cat1.id, cat2.id] }

      expect(assigns(:events)).to include(event_cat1, event_cat2)
      skip 'Implementation: Split category_ids[] array; apply filter (inherited from base)'
    end

    # AC15: Status filter
    skip '?status=draft shows only drafts' do
      event_draft = create(:event, platform:, organizer:, status: :draft, start_at: 1.week.from_now)
      event_confirmed = create(:event, platform:, organizer:, status: :confirmed, start_at: 1.week.from_now)

      get '/en/events', params: { status: 'draft' }

      expect(assigns(:events)).to include(event_draft)
      expect(assigns(:events)).not_to include(event_confirmed)
      skip 'Implementation: Pass status param to filter'
    end

    # AC16: Status union
    skip '?status[]=draft&status[]=confirmed shows drafts + confirmed (union)' do
      event_draft = create(:event, platform:, organizer:, status: :draft, start_at: 1.week.from_now)
      event_confirmed = create(:event, platform:, organizer:, status: :confirmed, start_at: 1.week.from_now)
      event_cancelled = create(:event, platform:, organizer:, status: :cancelled, start_at: 1.week.from_now)

      get '/en/events', params: { status: %w[draft confirmed] }

      expect(assigns(:events)).to include(event_draft, event_confirmed)
      expect(assigns(:events)).not_to include(event_cancelled)
      skip 'Implementation: Support status array for union filtering'
    end

    # AC17: Order-by flexibility
    skip '?order_by=latest orders furthest-first' do
      create(:event, platform:, organizer:, start_at: 1.week.from_now)
      far_event = create(:event, platform:, organizer:, start_at: 3.months.from_now)

      get '/en/events', params: { order_by: 'latest' }

      expect(assigns(:events).to_a.first).to eq(far_event)
      skip 'Implementation: Pass order_by param to filter'
    end

    # AC18: Pagination query params
    skip '?page=2&per_page=10 paginates correctly' do
      create_list(:event, 25, platform:, organizer:, start_at: 1.week.from_now)

      get '/en/events', params: { page: 2, per_page: 10 }

      expect(assigns(:events).current_page).to eq(2)
      expect(assigns(:events).length).to eq(10)
      skip 'Implementation: Pass page and per_page to filter'
    end

    # AC19: Authorization respects policy scope
    skip 'Authorization: respects policy scope (organizer sees own drafts)' do
      my_draft = create(:event, platform:, organizer: user, status: :draft, start_at: 1.week.from_now)
      other_draft = create(:event, platform:, organizer:, status: :draft, start_at: 1.week.from_now)
      confirmed = create(:event, platform:, organizer:, status: :confirmed, start_at: 1.week.from_now)

      get '/en/events'

      expect(assigns(:events)).to include(my_draft, confirmed)
      expect(assigns(:events)).not_to include(other_draft)
      skip 'Implementation: Apply policy scope in EventsController; organizers see own drafts'
    end
  end

  # ============================================================================
  # WEEK 3: FEATURE LAYER — Views, UX, Pagination, Mobile
  # ============================================================================

  describe 'Events index UX and pagination', tag: %i[acceptance_criteria ac_events feature week3] do
    let(:platform) { create(:platform) }
    let(:user) { create(:person, platform:) }
    let(:organizer) { create(:person, platform:) }
    let(:category) { create(:category, platform:) }

    before do
      sign_in user
      create_list(:event, 25, platform:, organizer:, start_at: 1.week.from_now)
    end

    # AC20: Filter sidebar renders with all controls
    skip 'Visit /en/events, see filter sidebar with all controls' do
      visit '/en/events'

      expect(page).to have_css('form', class: /list.form|filter/i)
      expect(page).to have_field('q', type: 'text')
      expect(page).to have_field('status', type: 'select')
      expect(page).to have_field('order_by', type: 'select')
      expect(page).to have_button('Search') # or 'Filter'
      skip 'Implementation: Render _list_form partial with status + order_by selects'
    end

    # AC21: Text search filters results
    skip 'Type in search box, submit form, results filter by title + description' do
      visit '/en/events'
      fill_in 'q', with: 'yoga'
      click_button 'Search'

      expect(page).to have_text('yoga')
      skip 'Implementation: Form action submits GET params; events re-render filtered'
    end

    # AC22: Category multi-select filters
    skip 'Check category checkboxes, results update' do
      visit '/en/events'
      check category.name
      click_button 'Search'

      expect(page).to have_css('.events') # Events render
      skip 'Implementation: Checkboxes for each category; submit filters'
    end

    # AC23: Status select filters
    skip 'Select status dropdown, results filter' do
      visit '/en/events'
      select 'Draft', from: 'status'
      click_button 'Search'

      expect(page).to have_css('.events')
      skip 'Implementation: Status select + form submission'
    end

    # AC24: Order-by select re-sorts (soonest/latest/newest/oldest)
    skip 'Select order-by, results re-sort (soonest/latest/newest/oldest all work)' do
      visit '/en/events'
      select 'Latest', from: 'order_by'
      click_button 'Search'

      expect(page).to have_css('.events')
      skip 'Implementation: Order-by select with 4 options; form submission'
    end

    # AC25: Per-page select changes window size
    skip 'Select per-page, page reloads with new window size' do
      visit '/en/events'
      select '10', from: 'per_page'
      click_button 'Search'

      event_count = page.all('.event-card').length
      expect(event_count).to be <= 10
      skip 'Implementation: Per-page select; form submission'
    end

    # AC26: Pagination links navigate correctly
    skip 'Pagination links present and navigate correctly' do
      visit '/en/events'

      expect(page).to have_css('.pagination')
      expect(page).to have_link('2')
      click_link '2'

      expect(page).to have_current_path(/page=2/)
      skip 'Implementation: <%= paginate @events %>'
    end

    # AC27: Clear filters link resets state to default (upcoming, soonest, 20 per page)
    skip '"Clear filters" link resets to default state (upcoming, soonest, 20 per page)' do
      visit '/en/events?status=draft&order_by=newest&per_page=10'

      expect(page).to have_link('Clear filters') # or similar
      click_link 'Clear filters'

      expect(page).to have_field('q', with: '')
      expect(page).to have_select('status', selected: 'All')
      expect(page).to have_select('order_by', selected: 'Soonest')
      skip 'Implementation: Clear link points to /events with no params (defaults handled by filter)'
    end

    # AC28: Mobile sidebar collapse
    skip 'Sidebar collapses on mobile (≤768px)' do
      page.driver.browser.manage.window.resize_to(360, 667)
      visit '/en/events'

      expect(page).to have_css('.sidebar', visible: false) # or collapsed state
      find('.sidebar-toggle').click

      expect(page).to have_css('.sidebar', visible: true)
      skip 'Implementation: CSS media query + JS toggle for ≤768px (same as Posts)'
    end
  end
end
# rubocop:enable RSpec/PendingWithoutReason, RSpec/DescribeClass
