# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for the Federation Hub and per-item federation consent',
               :docs_screenshot, :js, :skip_host_setup, retry: 0, type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let(:locale) { I18n.default_locale }
  let(:network_admin_email) { 'federation-hub-network-admin@example.test' }
  let(:member_email) { 'federation-hub-member@example.test' }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    seed_federation_hub_state!
  end

  after do
    Current.platform = nil
  end

  it 'captures the Federation Hub personal panel for a regular member' do
    capture_federation_hub_personal_panel
    expect(ENV.fetch('RUN_DOCS_SCREENSHOTS', nil)).to eq('1')
  end

  it 'captures the Federation Hub with the admin connection-health section' do
    capture_federation_hub_admin_view
    expect(ENV.fetch('RUN_DOCS_SCREENSHOTS', nil)).to eq('1')
  end

  it 'captures the federation activity feed for a network admin' do
    capture_federation_activity_feed
    expect(ENV.fetch('RUN_DOCS_SCREENSHOTS', nil)).to eq('1')
  end

  it 'captures the per-item federation_visibility field on the post edit form' do
    capture_post_federation_visibility_field
    expect(ENV.fetch('RUN_DOCS_SCREENSHOTS', nil)).to eq('1')
  end

  it 'captures the per-connection federation grants matrix on the post edit form' do
    capture_post_federation_content_grants_field
    expect(ENV.fetch('RUN_DOCS_SCREENSHOTS', nil)).to eq('1')
  end

  private

  def capture_docs_screenshot(slug, feature_set:, callouts: [], narrative: nil, &)
    BetterTogether::CapybaraScreenshotEngine.capture(
      slug,
      device: :both,
      metadata: screenshot_metadata(flow: slug, feature_set:),
      callouts:,
      narrative:,
      &
    )
  end

  def screenshot_metadata(flow:, feature_set:)
    {
      locale:,
      feature_set:,
      flow:,
      source_spec: self.class.metadata[:file_path]
    }
  end

  def host_platform
    @host_platform ||= configure_host_platform
  end

  def network_admin
    @network_admin ||= BetterTogether::User.find_by(email: network_admin_email) || create(
      :better_together_user, :confirmed, :network_admin,
      email: network_admin_email, password: 'SecureTest123!@#'
    )
  end

  def member
    @member ||= BetterTogether::User.find_by(email: member_email) || create(
      :better_together_user, :confirmed,
      email: member_email, password: 'SecureTest123!@#'
    )
  end

  def federated_post
    @federated_post ||= create(
      :better_together_post,
      creator: member.person,
      platform: host_platform,
      title: 'Community garden volunteer day recap',
      privacy: 'public',
      published_at: 1.day.ago,
      federation_visibility: 'federate'
    )
  end

  def excluded_page
    @excluded_page ||= create(
      :better_together_page,
      creator: member.person,
      platform: host_platform,
      title: 'Draft internal planning notes',
      privacy: 'public',
      published_at: 1.day.ago,
      federation_visibility: 'no_federate'
    )
  end

  def peer_platform
    @peer_platform ||= create(:better_together_platform, name: 'Neighbourhood Commons', external: true, privacy: 'private')
  end

  def connection
    @connection ||= create(
      :better_together_platform_connection, :active,
      source_platform: host_platform, target_platform: peer_platform,
      share_posts: true, content_sharing_policy: 'mirror_network_feed'
    )
  end

  def second_peer_platform
    @second_peer_platform ||= create(
      :better_together_platform, name: 'Riverside Neighbours Collective', external: true, privacy: 'private'
    )
  end

  def second_connection
    @second_connection ||= create(
      :better_together_platform_connection, :active,
      source_platform: host_platform, target_platform: second_peer_platform,
      share_posts: true, content_sharing_policy: 'mirror_network_feed'
    )
  end

  # rubocop:disable Metrics/AbcSize
  def seed_federation_hub_state!
    BetterTogether::AccessControlBuilder.seed_data
    network_admin
    member.person.update!(federate_content: true)

    BetterTogether::Activity.create!(trackable: federated_post, key: 'post.create', owner: member.person)
    excluded_page
    connection.mark_sync_succeeded!(item_count: 12)
    second_connection

    # Seed one explicit per-connection override so the matrix screenshot shows a
    # real "denied" row alongside a "platform_default" row, not two identical selects.
    federated_post.federation_content_grants_by_connection = { connection.id => 'denied' }
    federated_post.save!
  end
  # rubocop:enable Metrics/AbcSize

  def login_as_network_admin
    capybara_sign_in_user(network_admin_email, 'SecureTest123!@#')
    expect(page).to have_no_current_path(new_user_session_path(locale:), wait: 10)
  end

  def login_as_member
    capybara_sign_in_user(member_email, 'SecureTest123!@#')
    expect(page).to have_no_current_path(new_user_session_path(locale:), wait: 10)
  end

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def capture_federation_hub_personal_panel
    capture_docs_screenshot(
      'federation_hub_personal_panel',
      feature_set: 'federation_item_consent',
      callouts: [
        {
          id: 'recent_items',
          selector: '#federation-hub-recent-items',
          title: 'Recently updated content',
          bullets: ['Shows this member\'s own recent posts/pages/events with their federation badge.']
        },
        {
          id: 'visibility_counts',
          selector: '#federation-hub-visibility-counts',
          title: 'Federation visibility counts',
          bullets: ['Counts of this member\'s content by platform default / always federate / never federate.']
        }
      ],
      narrative: {
        title: 'Federation Hub -- Personal Panel',
        audience: %w[member developer],
        journey_step: 'As a member, I visit the Federation Hub to see which of my content is set to ' \
                      'federate, and confirm my per-item overrides took effect.',
        callouts: [
          { id: 'recent_items', title: 'Recently updated content',
            description: 'Each item shows its current federation_visibility badge.' },
          { id: 'visibility_counts', title: 'Federation visibility counts',
            description: 'A quick tally by tri-state value across the member\'s own content.' }
        ],
        accessibility_notes: 'Counts use a <dl> with labelled <dt>/<dd> pairs; badges are text, not color-only.'
      }
    ) do
      login_as_member
      visit better_together.federation_hub_path(locale:)

      expect(page).to have_css('.bt-federation-hub-my-content')
      expect(page).to have_text(federated_post.title)
      expect(page).to have_no_css('.bt-federation-hub-connection-health')
    end
  end

  def capture_federation_hub_admin_view
    capture_docs_screenshot(
      'federation_hub_admin_view',
      feature_set: 'federation_item_consent',
      callouts: [
        {
          id: 'review_link',
          selector: '#federation-hub-review-connections-link',
          title: 'Review connections',
          bullets: ['Links out to the existing Host Dashboard federation-review table -- not duplicated here.']
        },
        {
          id: 'connection_badges',
          selector: '#federation-hub-connection-badges',
          title: 'Connection health at a glance',
          bullets: ['Total / pending / active / failed-sync counts for connections touching the host platform.']
        }
      ],
      narrative: {
        title: 'Federation Hub -- Admin Connection Health',
        audience: %w[platform_manager developer],
        journey_step: 'As a network admin, I check the Federation Hub for an at-a-glance view of ' \
                      'connection health before drilling into the full review queue.',
        callouts: [
          { id: 'connection_badges', title: 'Connection health at a glance',
            description: 'Summary counts only -- the detailed table stays on the Host Dashboard.' },
          { id: 'review_link', title: 'Review connections', description: 'Deep link to the full review workflow.' }
        ],
        accessibility_notes: 'Badges are pill-shaped with text labels, not color-only indicators.'
      }
    ) do
      login_as_network_admin
      visit better_together.federation_hub_path(locale:)

      expect(page).to have_css('.bt-federation-hub-connection-health')
      expect(page).to have_text('Connected platforms')
    end
  end

  def capture_federation_activity_feed
    capture_docs_screenshot(
      'federation_hub_activity_feed',
      feature_set: 'federation_item_consent',
      callouts: [
        {
          id: 'activity_list',
          selector: '#federation-hub-activity-list',
          title: 'Federation activity feed',
          bullets: ['Combines the admin\'s own content activity with connection sync activity, paginated.']
        },
        {
          id: 'filters',
          selector: '#federation-hub-activity-filters',
          title: 'Content type and direction filters',
          bullets: ['Direction filter (incoming/outgoing) only appears for admins reviewing connection activity.']
        }
      ],
      narrative: {
        title: 'Federation Hub -- Activity Feed',
        audience: %w[platform_manager developer],
        journey_step: 'As a network admin, I open the activity feed to confirm a recent sync succeeded.',
        callouts: [
          { id: 'activity_list', title: 'Federation activity feed',
            description: 'Queries BetterTogether::Activity directly, bypassing the public-only policy scope.' },
          { id: 'filters', title: 'Filters', description: 'Narrow by content type or (admin-only) direction.' }
        ],
        accessibility_notes: 'Filter selects have visually-hidden labels; list items use a semantic <ul>/<li> structure.'
      }
    ) do
      login_as_network_admin
      visit better_together.federation_hub_activity_path(locale:)

      expect(page).to have_css('#federation-hub-activity-list')
      expect(page).to have_text('Sync succeeded')
    end
  end

  def capture_post_federation_visibility_field
    capture_docs_screenshot(
      'post_federation_visibility_field',
      feature_set: 'federation_item_consent',
      callouts: [
        {
          id: 'federation_field',
          selector: '[id$="_federation_visibility"]',
          title: 'Per-item federation override',
          bullets: [
            '"Use platform default" follows the member\'s global federation preference.',
            '"Never federate" always wins, even if the connection and global preference allow it.'
          ]
        }
      ],
      narrative: {
        title: 'Post Editor -- Federation Visibility Field',
        audience: %w[member developer],
        journey_step: 'As a member, I open one of my posts and set it to never federate, ' \
                      'overriding my own account-wide federation preference for just this item.',
        callouts: [
          { id: 'federation_field', title: 'Per-item federation override',
            description: 'A three-way select next to the existing privacy control.' }
        ],
        accessibility_notes: 'The select has an explicit <label for=...> pair and a visible hint below it.'
      }
    ) do
      login_as_member
      visit better_together.edit_post_path(federated_post, locale:)

      expect(page).to have_select('post[federation_visibility]')
      scroll_to_federation_field
    end
  end

  def capture_post_federation_content_grants_field
    capture_docs_screenshot(
      'post_federation_content_grants_field',
      feature_set: 'federation_item_consent',
      callouts: [
        {
          id: 'denied_row',
          selector: "#federation-content-grant-#{connection.id}",
          title: 'Per-connection override in effect',
          bullets: [
            'This connection is explicitly set to "Never federate," overriding the tri-state above ' \
            'for this one connection only.'
          ]
        },
        {
          id: 'grants_section',
          selector: '[id$="_federation_content_grants"]',
          title: 'Per-connection selection matrix',
          bullets: [
            'One row per active connection that allows posts -- independent of the federation_visibility ' \
            'tri-state above.',
            'Lets a member say "federate everywhere except this one connection" (or the reverse).'
          ]
        }
      ],
      narrative: {
        title: 'Post Editor -- Per-Connection Federation Grants',
        audience: %w[member developer],
        journey_step: 'As a member, I want this post to federate everywhere except Neighbourhood Commons, ' \
                      'so I set that one connection to "Never federate" without changing my overall ' \
                      'federation setting.',
        callouts: [
          { id: 'grants_section', title: 'Per-connection selection matrix',
            description: 'A row per eligible connection, each an independent allowed/denied/platform_default ' \
                         'select tied to a FederationContentGrant record.' },
          { id: 'denied_row', title: 'Per-connection override in effect',
            description: 'FederationContentGrant#status == "denied" for this connection wins over the ' \
                         'item\'s tri-state and the creator\'s global preference.' }
        ],
        accessibility_notes: 'Each select is paired with an explicit <label for=...>; the section has a ' \
                             'visible heading and hint text below it.'
      }
    ) do
      login_as_member
      visit better_together.edit_post_path(federated_post, locale:)

      expect(page).to have_select("post[federation_content_grants_by_connection][#{connection.id}]")
      expect(page).to have_select("post[federation_content_grants_by_connection][#{second_connection.id}]")
      scroll_to_federation_content_grants_field
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  def scroll_to_federation_field
    field = find('[id$="_federation_visibility"]', wait: 10)
    page.execute_script('arguments[0].scrollIntoView({block: "center", behavior: "instant"})', field.native)
  end

  def scroll_to_federation_content_grants_field
    field = find('[id$="_federation_content_grants"]', wait: 10)
    page.execute_script('arguments[0].scrollIntoView({block: "center", behavior: "instant"})', field.native)
  end
end
