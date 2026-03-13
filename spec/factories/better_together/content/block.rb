# frozen_string_literal: true

FactoryBot.define do
  factory :content_block_base, class: 'BetterTogether::Content::Block' do # rubocop:todo Lint/EmptyBlock
  end

  factory :content_people_block, class: 'BetterTogether::Content::PeopleBlock' do
    display_style { 'grid' }
    item_limit { 6 }
  end

  factory :content_communities_block, class: 'BetterTogether::Content::CommunitiesBlock' do
    display_style { 'grid' }
    item_limit { 6 }
  end

  factory :content_events_block, class: 'BetterTogether::Content::EventsBlock' do
    display_style { 'grid' }
    item_limit { 6 }
    event_scope { 'upcoming' }
  end

  factory :content_posts_block, class: 'BetterTogether::Content::PostsBlock' do
    display_style { 'grid' }
    item_limit { 6 }
    posts_scope { 'published' }
  end

  factory :content_checklist_block, class: 'BetterTogether::Content::ChecklistBlock' do
    display_style { 'grid' }
    item_limit { 6 }
    association :checklist_ref, factory: :checklist, strategy: :build
    after(:build) { |block, evaluator| block.checklist_id = evaluator.checklist_ref.id if evaluator.checklist_ref.persisted? }
  end

  factory :content_navigation_area_block, class: 'BetterTogether::Content::NavigationAreaBlock' do
    display_style { 'grid' }
    item_limit { 6 }
    association :nav_area_ref, factory: :navigation_area, strategy: :build
    after(:build) { |block, evaluator| block.navigation_area_id = evaluator.nav_area_ref.id if evaluator.nav_area_ref.persisted? }
  end
end
