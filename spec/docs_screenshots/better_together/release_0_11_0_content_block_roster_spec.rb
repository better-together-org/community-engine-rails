# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for the 0.11.0 content block roster',
               :docs_screenshot, :js, :skip_host_setup, retry: 0, type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let!(:chooser_page) do
    BetterTogether::Page.find_by(identifier: 'release-0-11-0-content-block-picker') ||
      create(
        :better_together_page,
        title: 'Release 0.11.0 Content Block Picker',
        slug: 'release-0-11-0-content-block-picker',
        identifier: 'release-0-11-0-content-block-picker',
        protected: false,
        privacy: 'public',
        show_title: true,
        published_at: 1.day.ago
      )
  end
  let!(:release_checklist) do
    create(:better_together_checklist, title: 'Release 0.11.0 Launch Checklist')
  end
  let!(:release_checklist_item) do
    create(:better_together_checklist_item, checklist: release_checklist, label: 'Publish updated docs', position: 0)
  end
  let!(:release_community) do
    BetterTogether::Community.find_by(identifier: 'release-0-11-0-community') ||
      create(
        :better_together_community,
        identifier: 'release-0-11-0-community',
        name: 'Release 0.11.0 Community',
        description: 'Launch partners coordinating documentation, federation, and onboarding improvements.',
        privacy: 'public'
      )
  end
  let!(:release_person) do
    BetterTogether::Person.find_by(identifier: 'release-0-11-0-community-steward') ||
      create(
        :better_together_person,
        identifier: 'release-0-11-0-community-steward',
        name: 'Release 0.11.0 Community Steward',
        description: 'Coordinates onboarding, moderation, and release follow-through.',
        privacy: 'public',
        community: release_community
      )
  end
  let!(:release_post) do
    BetterTogether::Post.find_by(identifier: 'release-0-11-0-product-brief') ||
      create(
        :better_together_post,
        identifier: 'release-0-11-0-product-brief',
        title: 'Release 0.11.0 Product Brief',
        content: 'A concise operator-facing summary of the 0.11.0 release.',
        published_at: 1.day.ago,
        author: release_person
      )
  end
  let!(:release_event) do
    BetterTogether::Event.find_by(identifier: 'release-0-11-0-planning-circle') ||
      create(
        :event,
        identifier: 'release-0-11-0-planning-circle',
        name: 'Release 0.11.0 Planning Circle',
        description: 'A hosted review of the new blocks and release readiness.',
        privacy: 'public',
        starts_at: 3.days.from_now,
        ends_at: 3.days.from_now + 90.minutes,
        registration_url: 'https://communityengine.app/events/release-0-11-0',
        timezone: 'America/St_Johns',
        creator: release_person
      )
  end
  let!(:release_navigation_area) do
    create(
      :navigation_area,
      name: "Release 0.11.0 Quick Links #{SecureRandom.hex(4)}",
      style: 'stacked',
      visible: true,
      navigable_type: 'BetterTogether::Community',
      navigable_id: release_community.id,
      protected: false
    )
  end
  let!(:release_navigation_item) do
    create(
      :navigation_item,
      navigation_area: release_navigation_area,
      title: 'Review the release notes',
      url: 'https://communityengine.app/releases/0.11.0',
      icon: 'book-open',
      position: 0,
      visible: true,
      item_type: 'link',
      protected: false
    )
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = configure_host_platform
    release_checklist_item
    release_navigation_item
  end

  after do
    Current.platform = nil
  end

  it 'captures the release content block chooser, editor forms, and rendered examples' do
    capture_add_block_list
    block_definitions.each do |definition|
      capture_editor_form(definition)
      capture_render_example(definition)
    end

    expect(ENV.fetch('RUN_DOCS_SCREENSHOTS', nil)).to eq('1')
  end

  private

  def capture_docs_screenshot(slug, flow:, &)
    BetterTogether::CapybaraScreenshotEngine.capture(
      slug,
      device: :desktop,
      metadata: {
        locale: I18n.default_locale,
        role: 'platform_manager',
        feature_set: 'release_0_11_0_content_block_roster',
        flow:,
        source_spec: self.class.metadata[:file_path]
      },
      &
    )
  end

  def login_for_docs_capture
    capybara_login_as_platform_manager
    expect(page).to have_no_current_path(new_user_session_path(locale: I18n.default_locale), wait: 10)
  end

  def capture_add_block_list
    capture_docs_screenshot('release_0_11_0_content_block_add_list', flow: 'page_block_add_list') do
      login_for_docs_capture
      visit better_together.edit_page_path(chooser_page.slug, locale: I18n.default_locale)
      click_button 'Add Block'

      block_definitions.each do |definition|
        expect(page).to have_link(definition[:label])
      end
    end
  end

  # rubocop:disable Metrics/MethodLength
  def block_definitions
    @block_definitions ||= [
      {
        key: 'accordion_block',
        label: 'Accordion',
        block_type: 'BetterTogether::Content::AccordionBlock',
        factory: :content_accordion_block,
        page_title: 'Release 0.11.0 Accordion Block',
        expected_render_text: ['What is this?', 'A community platform.']
      },
      {
        key: 'alert_block',
        label: 'Alert',
        block_type: 'BetterTogether::Content::AlertBlock',
        factory: :content_alert_block,
        page_title: 'Release 0.11.0 Alert Block',
        expected_render_text: ['This is an important notice.']
      },
      {
        key: 'call_to_action_block',
        label: 'Call to Action',
        block_type: 'BetterTogether::Content::CallToActionBlock',
        factory: :content_call_to_action_block,
        page_title: 'Release 0.11.0 Call to Action Block',
        expected_render_text: ['Join our community', 'Get started']
      },
      {
        key: 'checklist_block',
        label: 'Checklist',
        block_type: 'BetterTogether::Content::ChecklistBlock',
        factory: :content_checklist_block,
        page_title: 'Release 0.11.0 Checklist Block',
        expected_render_text: ['Release 0.11.0 Launch Checklist', 'Publish updated docs']
      },
      {
        key: 'communities_block',
        label: 'Communities',
        block_type: 'BetterTogether::Content::CommunitiesBlock',
        factory: :content_communities_block,
        page_title: 'Release 0.11.0 Communities Block',
        expected_render_text: ['Release 0.11.0 Community']
      },
      {
        key: 'events_block',
        label: 'Events',
        block_type: 'BetterTogether::Content::EventsBlock',
        factory: :content_events_block,
        page_title: 'Release 0.11.0 Events Block',
        expected_render_text: ['Release 0.11.0 Planning Circle']
      },
      {
        key: 'iframe_block',
        label: 'Iframe',
        block_type: 'BetterTogether::Content::IframeBlock',
        factory: :content_iframe_block,
        page_title: 'Release 0.11.0 Iframe Block',
        expected_render_text: ['Community survey']
      },
      {
        key: 'navigation_area_block',
        label: 'Navigation Area',
        block_type: 'BetterTogether::Content::NavigationAreaBlock',
        factory: :content_navigation_area_block,
        page_title: 'Release 0.11.0 Navigation Area Block',
        expected_render_text: ['Review the release notes']
      },
      {
        key: 'people_block',
        label: 'People',
        block_type: 'BetterTogether::Content::PeopleBlock',
        factory: :content_people_block,
        page_title: 'Release 0.11.0 People Block',
        expected_render_text: ['Release 0.11.0 Community Steward']
      },
      {
        key: 'posts_block',
        label: 'Posts',
        block_type: 'BetterTogether::Content::PostsBlock',
        factory: :content_posts_block,
        page_title: 'Release 0.11.0 Posts Block',
        expected_render_text: ['Release 0.11.0 Product Brief']
      },
      {
        key: 'quote_block',
        label: 'Quote',
        block_type: 'BetterTogether::Content::QuoteBlock',
        factory: :content_quote_block,
        page_title: 'Release 0.11.0 Quote Block',
        expected_render_text: ['Together we are stronger.', 'Jane Smith']
      },
      {
        key: 'statistics_block',
        label: 'Statistics',
        block_type: 'BetterTogether::Content::StatisticsBlock',
        factory: :content_statistics_block,
        page_title: 'Release 0.11.0 Statistics Block',
        expected_render_text: ['Our Impact', 'Members']
      },
      {
        key: 'video_block',
        label: 'Video',
        block_type: 'BetterTogether::Content::VideoBlock',
        factory: :content_video_block,
        page_title: 'Release 0.11.0 Video Block',
        expected_render_text: ['Release 0.11.0 Video Block']
      }
    ].freeze
  end
  # rubocop:enable Metrics/MethodLength

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def capture_editor_form(definition)
    editor_page = BetterTogether::Page.find_or_initialize_by(identifier: "release-0-11-0-#{definition[:key]}-editor-page")
    editor_page.assign_attributes(
      title: "Release 0.11.0 #{definition[:label]} Editor",
      slug: "release-0-11-0-#{definition[:key]}-editor-page",
      protected: false,
      show_title: true,
      published_at: 1.day.ago,
      privacy: 'public',
      platform: Current.platform
    )
    editor_page.save!
    editor_page.page_blocks.destroy_all
    editor_page.page_blocks.create!(block: build_render_block(definition), position: 0)

    capture_docs_screenshot("release_0_11_0_#{definition[:key]}_editor", flow: 'page_block_editor') do
      login_for_docs_capture
      visit better_together.edit_page_path(editor_page.slug, locale: I18n.default_locale)

      within('.page-block-fields:first-of-type') do
        expect(page).to have_text(definition[:label])
        expect(page).to have_text('Identifier')
        expect(page).to have_css('input, select, textarea', minimum: 2, visible: :all)
      end

      page.execute_script('window.scrollTo(0, document.querySelector(".page-block-fields").getBoundingClientRect().top + window.scrollY - 40)')
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def capture_render_example(definition)
    render_page = BetterTogether::Page.find_or_initialize_by(identifier: "release-0-11-0-#{definition[:key]}-page")
    render_page.assign_attributes(
      title: definition[:page_title],
      slug: "release-0-11-0-#{definition[:key]}-page",
      protected: false,
      show_title: true,
      published_at: 1.day.ago,
      privacy: 'public',
      platform: Current.platform
    )
    render_page.save!
    render_block = build_render_block(definition)

    render_page.page_blocks.destroy_all
    render_page.page_blocks.create!(block: render_block, position: 0)

    capture_docs_screenshot("release_0_11_0_#{definition[:key]}_render", flow: 'page_block_render') do
      login_for_docs_capture
      visit better_together.page_path(render_page.slug, locale: I18n.default_locale)

      expect(page).to have_text(definition[:page_title])
      definition[:expected_render_text].each do |content_text|
        expect(page).to have_text(/#{Regexp.escape(content_text)}/i)
      end
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
  def build_render_block(definition)
    case definition[:key]
    when 'accordion_block'
      create(
        definition[:factory],
        heading: 'Release 0.11.0 Frequently Asked Questions',
        accordion_items_json: [
          { question: 'What is this?', answer: 'A community platform.' },
          { question: 'What shipped?', answer: 'New content block choices for page builders.' }
        ].to_json
      )
    when 'alert_block'
      create(
        definition[:factory],
        alert_level: 'warning',
        heading: 'Heads up',
        body_text: 'This is an important notice.'
      )
    when 'call_to_action_block'
      create(
        definition[:factory],
        heading: 'Join our community',
        subheading: 'Contribute feedback on the 0.11.0 release',
        body_text: 'Use the new block palette to build denser, more expressive landing pages.',
        primary_button_label: 'Get started',
        primary_button_url: 'https://communityengine.app/start',
        secondary_button_label: 'Read the notes',
        secondary_button_url: 'https://communityengine.app/releases/0.11.0'
      )
    when 'checklist_block'
      BetterTogether::Content::ChecklistBlock.create!(
        checklist_id: release_checklist.id,
        display_style: 'grid',
        item_limit: 1,
        resource_ids: [release_checklist.id].to_json
      )
    when 'communities_block'
      create(
        definition[:factory],
        resource_ids: [release_community.id].to_json,
        item_limit: 1
      )
    when 'events_block'
      create(
        definition[:factory],
        event_scope: 'upcoming',
        resource_ids: [release_event.id].to_json,
        item_limit: 1
      )
    when 'iframe_block'
      create(
        definition[:factory],
        iframe_url: 'https://forms.btsdev.ca/s/example',
        title_en: 'Community survey',
        caption_en: 'An embedded feedback form for release-readiness input.'
      )
    when 'navigation_area_block'
      BetterTogether::Content::NavigationAreaBlock.create!(
        navigation_area_id: release_navigation_area.id
      )
    when 'people_block'
      create(
        definition[:factory],
        resource_ids: [release_person.id].to_json,
        item_limit: 1
      )
    when 'posts_block'
      create(
        definition[:factory],
        posts_scope: 'published',
        resource_ids: [release_post.id].to_json,
        item_limit: 1
      )
    when 'quote_block'
      create(
        definition[:factory],
        quote_text: 'Together we are stronger.',
        attribution_name: 'Jane Smith',
        attribution_title: 'Community Organizer',
        attribution_organization: 'Better Together'
      )
    when 'statistics_block'
      create(
        definition[:factory],
        heading: 'Our Impact',
        columns: '3',
        stats_json: [
          { label: 'Members', value: '500', icon: 'fas fa-users' },
          { label: 'Events', value: '42', icon: 'fas fa-calendar' },
          { label: 'Partners', value: '18', icon: 'fas fa-handshake' }
        ].to_json
      )
    when 'video_block'
      create(
        definition[:factory],
        video_url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        caption: 'Release walkthrough video'
      )
    else
      create(definition[:factory])
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
end
