# frozen_string_literal: true

FactoryBot.define do
  factory :content_block_base, class: 'BetterTogether::Content::Block' do
    privacy { 'public' }
    association :platform, factory: :better_together_platform
  end

  factory :content_people_block, class: 'BetterTogether::Content::PeopleBlock' do
    privacy { 'public' }
    display_style { 'grid' }
    item_limit { 6 }
  end

  factory :content_communities_block, class: 'BetterTogether::Content::CommunitiesBlock' do
    privacy { 'public' }
    display_style { 'grid' }
    item_limit { 6 }
  end

  factory :content_events_block, class: 'BetterTogether::Content::EventsBlock' do
    privacy { 'public' }
    display_style { 'grid' }
    item_limit { 6 }
    event_scope { 'upcoming' }
  end

  factory :content_posts_block, class: 'BetterTogether::Content::PostsBlock' do
    privacy { 'public' }
    display_style { 'grid' }
    item_limit { 6 }
    posts_scope { 'published' }
  end

  factory :content_checklist_block, class: 'BetterTogether::Content::ChecklistBlock' do
    privacy { 'public' }
    display_style { 'grid' }
    item_limit { 6 }
    association :checklist_ref, factory: :checklist, strategy: :build
    after(:build) do |block, evaluator|
      block.checklist_id = evaluator.checklist_ref.id if evaluator.checklist_ref.persisted?
    end
  end

  factory :content_navigation_area_block, class: 'BetterTogether::Content::NavigationAreaBlock' do
    privacy { 'public' }
    display_style { 'grid' }
    item_limit { 6 }
    association :nav_area_ref, factory: :navigation_area, strategy: :build
    after(:build) do |block, evaluator|
      block.navigation_area_id = evaluator.nav_area_ref.id if evaluator.nav_area_ref.persisted?
    end
  end

  factory :content_call_to_action_block, class: 'BetterTogether::Content::CallToActionBlock' do
    privacy { 'public' }
    layout { 'centered' }
    heading_en { 'Join our community' }
    subheading_en { '' }
    body_text_en { 'Click the button to get started.' }
    primary_button_label_en { 'Get started' }
    primary_button_url_en { 'https://example.com' }
    secondary_button_label_en { '' }
    secondary_button_url_en { '' }
  end

  factory :content_alert_block, class: 'BetterTogether::Content::AlertBlock' do
    privacy { 'public' }
    alert_level { 'info' }
    heading_en { '' }
    body_text_en { 'This is an important notice.' }
  end

  factory :content_quote_block, class: 'BetterTogether::Content::QuoteBlock' do
    privacy { 'public' }
    quote_text_en { 'Together we are stronger.' }
    attribution_name_en { 'Jane Smith' }
    attribution_title_en { '' }
    attribution_organization_en { '' }
  end

  factory :content_statistics_block, class: 'BetterTogether::Content::StatisticsBlock' do
    privacy { 'public' }
    heading_en { 'Our Impact' }
    columns { '3' }
    stats_json_en { '[{"label":"Members","value":"500","icon":"fas fa-users"}]' }
  end

  factory :content_video_block, class: 'BetterTogether::Content::VideoBlock' do
    privacy { 'public' }
    video_url { 'https://www.youtube.com/watch?v=dQw4w9WgXcQ' }
    aspect_ratio { '16x9' }
    caption_en { '' }
  end

  factory :content_iframe_block, class: 'BetterTogether::Content::IframeBlock' do
    privacy { 'public' }
    iframe_url_en { 'https://forms.btsdev.ca/s/example' }
    aspect_ratio { '16x9' }
    title_en { 'Community survey' }
    caption_en { '' }
  end

  factory :content_accordion_block, class: 'BetterTogether::Content::AccordionBlock' do
    privacy { 'public' }
    heading_en { 'FAQ' }
    accordion_items_json_en { '[{"question":"What is this?","answer":"A community platform."}]' }
    open_first { 'true' }
  end
end
