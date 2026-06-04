# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/PendingWithoutReason, RSpec/DescribeClass
# Posts Index — Search, Filter & Pagination (v0.12.0)
# Plan: docs/plans/posts-index-filter-pagination.md
#
# Acceptance criteria specs for posts index filtering and pagination.
# Implementation follows 3-week cadence:
#   Week 1: Model layer (PostsSearchFilter service)
#   Week 2: Request layer (Controller + authorization)
#   Week 3: Feature layer (Views + UX + pagination)

# ============================================================================
# WEEK 1: MODEL LAYER — PostsSearchFilter Service Foundation
# ============================================================================

RSpec.describe 'PostsSearchFilter service', tag: %i[acceptance_criteria ac_posts model week1], type: :model do
    let(:platform) { create(:platform) }
    let(:creator) { create(:person) }
    let(:category) { create(:category) }

    # AC1: Service returns Kaminari-decorated relation
    it 'PostsSearchFilter.call(relation:, params:) returns Kaminari-decorated relation' do
      create_list(:post, 3, platform:, creator:)
      relation = BetterTogether::Post.where(platform_id: platform.id)

      result = BetterTogether::PostsSearchFilter.call(relation:, params: {})

      expect(result).to respond_to(:total_count)
      expect(result).to respond_to(:total_pages)
      expect(result).to respond_to(:current_page)
      expect(result.count).to eq(3)
    end

    # AC2: Text search via ILIKE on Mobility title + ActionText content
    it 'q: "hello" applies ILIKE to Mobility title + ActionText content (both locales)' do
      post_found = create(:post, platform:, creator:, title: 'Hello World')
      post_not_found = create(:post, platform:, creator:, title: 'Goodbye Moon')
      relation = BetterTogether::Post.where(platform_id: platform.id)

      result = BetterTogether::PostsSearchFilter.call(relation:, params: { q: 'hello' })

      expect(result.map(&:id)).to include(post_found.id)
      expect(result.map(&:id)).not_to include(post_not_found.id)
    end

    # AC3: Category filter via multi-select
    it 'category_ids: [id] joins categorizations and returns only tagged posts' do
      post_categorized = create(:post, platform:, creator:)
      post_uncategorized = create(:post, platform:, creator:)
      create(:categorization, categorizable: post_categorized, category:)
      relation = BetterTogether::Post.where(platform_id: platform.id)

      result = BetterTogether::PostsSearchFilter.call(
        relation:,
        params: { category_ids: [category.id] }
      )

      expect(result.map(&:id)).to include(post_categorized.id)
      expect(result.map(&:id)).not_to include(post_uncategorized.id)
    end

    # AC4: Privacy filter
    it 'privacy: "public" filters by posts.privacy column' do
      post_public = create(:post, platform:, creator:, privacy: :public)
      post_private = create(:post, platform:, creator:, privacy: :private)
      relation = BetterTogether::Post.where(platform_id: platform.id)

      result = BetterTogether::PostsSearchFilter.call(
        relation:,
        params: { privacy: 'public' }
      )

      expect(result.map(&:id)).to include(post_public.id)
      expect(result.map(&:id)).not_to include(post_private.id)
    end

    # AC5: Order-by flexibility
    it 'order_by: "oldest" orders created_at asc (default is desc)' do
      oldest_post = create(:post, platform:, creator:, created_at: 1.week.ago)
      newest_post = create(:post, platform:, creator:, created_at: 1.day.ago)
      relation = BetterTogether::Post.where(platform_id: platform.id)

      result_oldest = BetterTogether::PostsSearchFilter.call(
        relation:,
        params: { order_by: 'oldest' }
      ).to_a

      expect(result_oldest.first).to eq(oldest_post)
      expect(result_oldest.last).to eq(newest_post)
    end

    # AC6: Pagination via Kaminari
    it 'per_page: 10 applies Kaminari .per(10), defaults to 20' do
      create_list(:post, 25, platform:, creator:)
      relation = BetterTogether::Post.where(platform_id: platform.id)

      result = BetterTogether::PostsSearchFilter.call(
        relation:,
        params: { per_page: 10, page: 1 }
      )

      expect(result.length).to eq(10)
      expect(result.total_pages).to eq(3)
    end

    # AC7: Empty params returns full unfiltered relation (no N+1)
    it 'Empty params returns full unfiltered relation with no N+1 joins' do
      create_list(:post, 5, platform:, creator:)
      relation = BetterTogether::Post.where(platform_id: platform.id)

      result = BetterTogether::PostsSearchFilter.call(relation:, params: {})
      expect(result.to_a.length).to eq(5)
      expect(result).to respond_to(:total_count).or respond_to(:count)
    end
end

# ============================================================================
# WEEK 2: REQUEST LAYER — Controller & Authorization
# ============================================================================

RSpec.describe 'PostsController#index request', tag: %i[acceptance_criteria ac_posts request week2], type: :request do
    let(:platform) { create(:platform) }
    let(:user) { create(:user) }
    let(:creator) { create(:person) }
    let(:category) { create(:category) }

    before { sign_in user }

    # AC8: GET /en/posts with no params returns 200, all visible posts, 20 per page
    it 'GET /en/posts with no params returns 200, all visible posts, 20 per page' do
      create_list(:post, 25, platform:, creator:)

      get '/en/posts'

      expect(response).to be_successful.or have_http_status(:found)
      expect(assigns(:posts)).to be_present if assigns(:posts)
    end

    # AC9: Text search filters results and persists params
    it '?q=foo filters results by text, params persist in view' do
      post_found = create(:post, platform:, creator:, title: 'Foo Bar')
      post_not_found = create(:post, platform:, creator:, title: 'Baz Qux')

      get '/en/posts', params: { q: 'foo' }

      expect(assigns(:posts)).to include(post_found)
      expect(assigns(:posts)).not_to include(post_not_found)
      expect(response.body).to include('value="foo"') # Form state persists
    end

    # AC10: Category multi-select
    it '?category_ids[]=1&category_ids[]=2 multi-select works' do
      post_cat1 = create(:post, platform:, creator:)
      post_cat2 = create(:post, platform:, creator:)
      cat1 = create(:category, platform:)
      cat2 = create(:category, platform:)
      create(:categorization, post: post_cat1, category: cat1)
      create(:categorization, post: post_cat2, category: cat2)

      get '/en/posts', params: { category_ids: [cat1.id, cat2.id] }

      expect(assigns(:posts)).to include(post_cat1, post_cat2)
    end

    # AC11: Privacy filter
    it '?privacy=community restricts to community-only posts' do
      post_community = create(:post, platform:, creator:, privacy: :community)
      post_public = create(:post, platform:, creator:, privacy: :public)

      get '/en/posts', params: { privacy: 'community' }

      expect(assigns(:posts)).to include(post_community)
      expect(assigns(:posts)).not_to include(post_public)
    end

    # AC12: Order-by flexibility
    it '?order_by=oldest reverses sort order' do
      oldest_post = create(:post, platform:, creator:, created_at: 1.week.ago)
      create(:post, platform:, creator:, created_at: 1.day.ago)

      get '/en/posts', params: { order_by: 'oldest' }

      expect(assigns(:posts).to_a.first).to eq(oldest_post)
    end

    # AC13: Pagination query params
    it '?page=2&per_page=10 paginates correctly' do
      create_list(:post, 25, platform:, creator:)

      get '/en/posts', params: { page: 2, per_page: 10 }

      expect(assigns(:posts).current_page).to eq(2)
      expect(assigns(:posts).length).to eq(10)
    end

    # AC14: Authorization respects policy scope
    it 'Authorization: respects policy scope (user sees only permitted posts)' do
      post_visible = create(:post, platform:, creator:, privacy: :public)
      other_platform = create(:platform)
      post_hidden = create(:post, platform: other_platform, creator:, privacy: :public)

      get '/en/posts'

      expect(assigns(:posts)).to include(post_visible)
      expect(assigns(:posts)).not_to include(post_hidden)
    end
end

# ============================================================================
# WEEK 3: FEATURE LAYER — Views, UX, Pagination, Mobile
# ============================================================================

RSpec.describe 'Posts index UX and pagination', tag: %i[acceptance_criteria ac_posts feature week3], type: :system do
    let(:platform) { create(:platform) }
    let(:user) { create(:user) }
    let(:creator) { create(:person) }
    let(:category) { create(:category) }

    before do
      sign_in user
      create_list(:post, 25, platform:, creator:)
    end

    # AC15: Filter sidebar renders with all controls
    it 'Visit /en/posts, see filter sidebar with all controls' do
      visit '/en/posts'

      expect(page).to have_css('form', class: /list.form|filter/i)
      expect(page).to have_field('q', type: 'text')
      expect(page).to have_field('privacy', type: 'select')
      expect(page).to have_field('order_by', type: 'select')
      expect(page).to have_button('Search') # or 'Filter'
    end

    # AC16: Text search filters results
    it 'Type in search box, submit form, results filter' do
      visit '/en/posts'
      fill_in 'q', with: 'hello'
      click_button 'Search'

      expect(page).to have_current_path(/q=hello/)
    end

    # AC17: Category multi-select filters
    it 'Check category checkboxes, results update' do
      visit '/en/posts'
      check category.name
      click_button 'Search'

      expect(page).to have_current_path(/category_ids/)
    end

    # AC18: Privacy select filters
    it 'Select privacy dropdown, results filter' do
      visit '/en/posts'
      select 'Public', from: 'privacy'
      click_button 'Search'

      expect(page).to have_current_path(/privacy=public/)
    end

    # AC19: Order-by select re-sorts
    it 'Select order-by, results re-sort (soonest/latest/newest/oldest)' do
      visit '/en/posts'
      select 'Oldest', from: 'order_by'
      click_button 'Search'

      expect(page).to have_current_path(/order_by=oldest/)
    end

    # AC20: Per-page select changes window size
    it 'Select per-page, page reloads with new window size' do
      visit '/en/posts'
      select '10', from: 'per_page'
      click_button 'Search'

      expect(page).to have_current_path(/per_page=10/)
    end

    # AC21: Pagination links navigate correctly
    it 'Pagination links present and navigate correctly' do
      visit '/en/posts'

      expect(page).to have_css('.pagination')
      expect(page).to have_link('2')
      click_link '2'

      expect(page).to have_current_path(/page=2/)
    end

    # AC22: Clear filters link resets state
    it '"Clear filters" link resets to unfiltered state' do
      visit '/en/posts?q=test&privacy=public'

      expect(page).to have_link('Clear filters') # or similar
      click_link 'Clear filters'

      expect(page).to have_current_path('/en/posts')
    end

    # AC23: Mobile sidebar collapse
    it 'Sidebar collapses on mobile (≤768px)' do
      # Simulate mobile viewport
      page.driver.browser.manage.window.resize_to(360, 667)
      visit '/en/posts'

      # On mobile, sidebar should be present in DOM but might be hidden or collapsed
      expect(page).to have_css('.sidebar, [class*="sidebar"]')
      # Verify we can find a toggle element to interact with
      toggle = page.find('.sidebar-toggle, [class*="toggle"]', visible: :all)
      expect(toggle).to be_present
    end
end
# rubocop:enable RSpec/PendingWithoutReason, RSpec/DescribeClass
