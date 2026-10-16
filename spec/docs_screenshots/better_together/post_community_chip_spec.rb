# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for the post community chip', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers
  include ActionView::RecordIdentifier

  let(:manager) { find_or_create_test_user('manager@example.test', 'SecureTest123!@#', :platform_manager) }
  let(:host_platform) do
    configure_host_platform.tap do |platform|
      platform.update!(privacy: 'public', requires_invitation: false, allow_membership_requests: false)
    end
  end
  let!(:community) { create(:better_together_community, privacy: 'public', name: 'Corner Brook Online') }
  let!(:other_community) { create(:better_together_community, privacy: 'public', name: 'Humber Valley Makers') }
  let!(:post_record) do
    create(:better_together_post, title: 'Mill cam timelapse, 12 October', community:, platform: host_platform,
                                  privacy: 'public', published_at: 1.day.ago, creator: manager.person)
  end
  let!(:other_post) do
    create(:better_together_post, title: 'Spring maker meetup recap', community: other_community,
                                  platform: host_platform, privacy: 'public', published_at: 2.days.ago,
                                  creator: manager.person)
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
  end

  after { Current.platform = nil }

  def screenshot_metadata(flow:, role:)
    {
      locale: I18n.default_locale,
      role:,
      feature_set: 'post_community_chip',
      flow:,
      source_spec: self.class.metadata[:file_path]
    }
  end

  def chip_callout(selector)
    {
      id: 'community_chip',
      selector:,
      title: 'Community chip',
      bullets: ['Links to the post\'s community.']
    }
  end

  it 'captures the chip on post cards in the posts index' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'post_community_chip_index',
      device: :both,
      metadata: screenshot_metadata(flow: 'post_community_chip_index', role: 'platform_manager'),
      callouts: [chip_callout("##{dom_id(post_record)} .community-chip")],
      narrative: {
        title: 'Posts index: community chip',
        audience: %w[member content_editor developer],
        journey_step: 'As a reader of the posts feed, I can see which community each post comes from.',
        callouts: [{ id: 'community_chip', title: 'Community chip',
                     description: 'Profile image and name of the owning community, linked to its page.' }],
        accessibility_notes: 'The chip is a text link with a title; the profile image has empty alt text.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.posts_path(locale: I18n.default_locale)
      expect(page).to have_css('.community-chip', text: 'Humber Valley Makers')
    end
  end

  it 'captures the chip on the post show page' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'post_community_chip_show',
      device: :both,
      metadata: screenshot_metadata(flow: 'post_community_chip_show', role: 'platform_manager'),
      callouts: [chip_callout("##{dom_id(post_record, :community)} .community-chip")],
      narrative: {
        title: 'Post show page: community chip',
        audience: %w[member content_editor developer],
        journey_step: 'As a reader of a post, I can see which community published it.',
        callouts: [{ id: 'community_chip', title: 'Community chip',
                     description: 'Shown beside the privacy badge and date in the post byline.' }],
        accessibility_notes: 'Same link and image treatment as the card chip.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.post_path(post_record, locale: I18n.default_locale)
      expect(page).to have_css('.community-chip', text: 'Corner Brook Online')
    end
  end

  it 'captures the unannotated chip on post cards' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'post_community_chip_index_plain',
      device: :both,
      metadata: screenshot_metadata(flow: 'post_community_chip_index_plain', role: 'platform_manager')
    ) do
      capybara_login_as_platform_manager
      visit better_together.posts_path(locale: I18n.default_locale)
      expect(page).to have_css('.community-chip', text: 'Humber Valley Makers')
      scroll_to(find("##{dom_id(post_record)} .community-chip"), align: :center)
    end
  end

  it 'captures the unannotated chip on the post show page' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'post_community_chip_show_plain',
      device: :both,
      metadata: screenshot_metadata(flow: 'post_community_chip_show_plain', role: 'platform_manager')
    ) do
      visit better_together.post_path(post_record, locale: I18n.default_locale)
      expect(page).to have_css('.community-chip', text: 'Corner Brook Online')
      scroll_to(find("##{dom_id(post_record, :community)} .community-chip"), align: :center)
    end
  end
end
