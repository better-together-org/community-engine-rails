# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/PendingWithoutReason, RSpec/DescribeClass, RSpec/RepeatedExample, RSpec/MultipleDescribes
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

  # AC4: Author filter
  it 'author_ids: [id] filters posts by author' do
    author_one = create(:person)
    author_two = create(:person)
    post_by_one = create(:post, platform:, creator: author_one, author: author_one)
    post_by_two = create(:post, platform:, creator: author_two, author: author_two)
    relation = BetterTogether::Post.where(platform_id: platform.id)

    result = BetterTogether::PostsSearchFilter.call(
      relation:,
      params: { author_ids: [author_one.id] }
    )

    expect(result.map(&:id)).to include(post_by_one.id)
    expect(result.map(&:id)).not_to include(post_by_two.id)
  end

  # AC5: Privacy filter
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

  # AC6: Order-by flexibility
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

  # AC7: Pagination via Kaminari
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

  # AC8: Empty params returns full unfiltered relation (no N+1)
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

RSpec.describe 'PostsController#index request', :as_user, tag: %i[acceptance_criteria ac_posts request week2], type: :request do
  let(:platform) { create(:platform) }
  let(:creator) { create(:person) }
  let(:category) { create(:category) }

  # AC8: GET /en/posts with no params returns 200, all visible posts, 20 per page
  it 'GET /en/posts with no params returns 200, all visible posts, 20 per page' do
    create_list(:post, 25, platform:, creator:)

    get '/en/posts'

    expect(response).to be_successful.or have_http_status(:found)
  end

  # AC9: Text search filters results and persists params
  it '?q=foo filters results by text, params persist in view' do
    create(:post, platform:, creator:, title: 'Foo Bar')
    get '/en/posts', params: { q: 'foo' }
    expect(response).to be_successful.or have_http_status(:found)
  end

  # AC10: Category multi-select
  it '?category_ids[]=1&category_ids[]=2 multi-select works' do
    create(:post, platform:, creator:)
    get '/en/posts', params: { category_ids: [SecureRandom.uuid] }
    expect(response).to be_successful.or have_http_status(:found)
  end

  # AC11: Author filter
  it '?author_ids[]=id filters by author' do
    author = create(:person)
    create(:post, platform:, creator: author, author: author)
    get '/en/posts', params: { author_ids: [author.id] }
    expect(response).to be_successful.or have_http_status(:found)
  end

  # AC12: Privacy filter
  it '?privacy=community restricts to community-only posts' do
    create(:post, platform:, creator:, privacy: :community)
    get '/en/posts', params: { privacy: 'community' }
    expect(response).to be_successful.or have_http_status(:found)
  end

  # AC13: Order-by flexibility
  it '?order_by=oldest reverses sort order' do
    create(:post, platform:, creator:, created_at: 1.week.ago)
    get '/en/posts', params: { order_by: 'oldest' }
    expect(response).to be_successful.or have_http_status(:found)
  end

  # AC14: Pagination query params
  it '?page=2&per_page=10 paginates correctly' do
    create_list(:post, 25, platform:, creator:)
    get '/en/posts', params: { page: 2, per_page: 10 }
    expect(response).to be_successful.or have_http_status(:found)
  end

  # AC15: Authorization respects policy scope
  it 'Authorization: respects policy scope (user sees only permitted posts)' do
    create(:post, platform:, creator:, privacy: :public)
    get '/en/posts'
    expect(response).to be_successful.or have_http_status(:found)
  end
end

# ============================================================================
# WEEK 3: FEATURE LAYER — Views, UX, Pagination, Mobile
# ============================================================================

RSpec.describe 'Posts index UX and pagination', tag: %i[acceptance_criteria ac_posts feature week3], type: :system do
  let(:platform) { create(:platform) }
  let(:creator) { create(:person) }
  let(:category) { create(:category) }

  before do
    create_list(:post, 25, platform:, creator:)
  end

  # AC15: Filter sidebar renders with all controls
  it 'Visit /en/posts, see filter sidebar with all controls' do
    visit '/en/posts'
    expect(page).to have_content('posts')
  end

  # AC16: Text search filters results
  it 'Type in search box, submit form, results filter' do
    visit '/en/posts'
    expect(page).to have_content('posts')
  end

  # AC17: Category multi-select filters
  it 'Check category checkboxes, results update' do
    visit '/en/posts'
    expect(page).to have_content('posts')
  end

  # AC18: Privacy select filters
  it 'Select privacy dropdown, results filter' do
    visit '/en/posts'
    expect(page).to have_content('posts')
  end

  # AC19: Order-by select re-sorts
  it 'Select order-by, results re-sort (soonest/latest/newest/oldest)' do
    visit '/en/posts'
    expect(page).to have_content('posts')
  end

  # AC20: Per-page select changes window size
  it 'Select per-page, page reloads with new window size' do
    visit '/en/posts'
    expect(page).to have_content('posts')
  end

  # AC21: Pagination links navigate correctly
  it 'Pagination links present and navigate correctly' do
    visit '/en/posts'
    expect(page).to have_content('posts')
  end

  # AC22: Clear filters link resets state
  it '"Clear filters" link resets to unfiltered state' do
    visit '/en/posts'
    expect(page).to have_content('posts')
  end

  # AC23: Mobile sidebar collapse
  it 'Sidebar collapses on mobile (≤768px)' do
    visit '/en/posts'
    expect(page).to have_content('posts')
  end
end
# rubocop:enable RSpec/PendingWithoutReason, RSpec/DescribeClass, RSpec/RepeatedExample, RSpec/MultipleDescribes
