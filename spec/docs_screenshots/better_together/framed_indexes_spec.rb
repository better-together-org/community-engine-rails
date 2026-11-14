# frozen_string_literal: true

require 'rails_helper'

# Capture command (run from repo root):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 bundle exec prspec \
#     spec/docs_screenshots/better_together/framed_indexes_spec.rb'
# The embedded (turbo-frame) layout is captured with the community page tabs; these are the same indexes
# scoped to one community as plain pages.
RSpec.describe 'Documentation screenshots for community scoped indexes', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let(:locale) { I18n.default_locale }
  let(:host_platform) do
    configure_host_platform.tap { |platform| platform.update!(privacy: 'public', host_url: 'http://www.example.com') }
  end
  let(:manager) { find_or_create_test_user('manager@example.test', 'SecureTest123!@#', :platform_manager) }
  let(:community) { create(:community, name: 'Harbour Arts Collective', creator: manager.person) }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    3.times do |i|
      event = create(:event, platform: host_platform, creator: manager.person, name: "Harbour Arts Night #{i + 1}",
                             starts_at: (i + 2).days.from_now, ends_at: (i + 2).days.from_now + 2.hours)
      event.event_hosts.destroy_all
      event.event_hosts.create!(host: community)
    end
    create(:post, platform: host_platform, community:, creator: manager.person, title: 'Gallery update')
  end

  after { Current.platform = nil }

  def metadata(flow)
    { locale:, role: 'platform_manager', feature_set: 'community_scoped_indexes', flow:,
      source_spec: self.class.metadata[:file_path] }
  end

  it 'captures the community scoped events index' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'framed_indexes_events', device: :both, metadata: metadata('events'),
                               callouts: [
                                 { id: 'new_event', selector: '#new-event-btn', title: 'New event',
                                   bullets: ['Pre-selects the community as the host.'] },
                                 { id: 'filters', selector: '#events-filter-toggle', title: 'Filters',
                                   bullets: ['Keeps ?community_id= when applied or cleared.'] },
                                 { id: 'list', selector: '#events', title: 'Hosted events',
                                   bullets: ['Only events this community hosts, through the policy scope.'] }
                               ],
                               narrative: {
                                 title: 'Events index scoped to a community',
                                 audience: %w[community_member developer],
                                 journey_step: 'As a visitor, I see only the events a community hosts.',
                                 callouts: [
                                   { id: 'new_event', title: 'New event', description: 'Host is the scoped community.' },
                                   { id: 'filters', title: 'Filters', description: 'The scope survives filtering.' },
                                   { id: 'list', title: 'Hosted events', description: 'Policy scope still applies.' }
                                 ],
                                 accessibility_notes: 'The filter toggle is a native button with aria-expanded and aria-controls.'
                               }
    ) do
      capybara_login_as_platform_manager
      visit better_together.events_path(locale:, community_id: community.slug)
      expect(page).to have_css('#events .event-card', minimum: 3)
    end
  end

  it 'captures the plain community scoped events index' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'framed_indexes_events_plain', device: :both, metadata: metadata('events_plain')
    ) do
      capybara_login_as_platform_manager
      visit better_together.events_path(locale:, community_id: community.slug)
      expect(page).to have_css('#events .event-card', minimum: 3)
    end
  end

  it 'captures the community scoped posts index' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'framed_indexes_posts', device: :both, metadata: metadata('posts'),
                              callouts: [
                                { id: 'filters', selector: '#posts-filter-toggle', title: 'Filters',
                                  bullets: ['A collapsible filter, as on the events index.'] },
                                { id: 'list', selector: '#posts', title: 'Community posts',
                                  bullets: ['Posts of this community only.'] }
                              ],
                              narrative: {
                                title: 'Posts index scoped to a community',
                                audience: %w[community_member developer],
                                journey_step: 'As a visitor, I read the posts of one community.',
                                callouts: [
                                  { id: 'filters', title: 'Filters', description: 'Collapsible at every width when embedded.' },
                                  { id: 'list', title: 'Community posts', description: 'Scoped by community_id.' }
                                ],
                                accessibility_notes: 'The filter toggle is a native button with aria-expanded and aria-controls.'
                              }
    ) do
      capybara_login_as_platform_manager
      visit better_together.posts_path(locale:, community_id: community.slug)
      expect(page).to have_css('#posts')
    end
  end

  it 'captures the plain community scoped posts index' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'framed_indexes_posts_plain', device: :both, metadata: metadata('posts_plain')
    ) do
      capybara_login_as_platform_manager
      visit better_together.posts_path(locale:, community_id: community.slug)
      expect(page).to have_css('#posts')
    end
  end
end
