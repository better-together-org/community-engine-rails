# frozen_string_literal: true

# Capture command (run from repo root):
#   RUN_DOCS_SCREENSHOTS=1 bin/dc-run bundle exec prspec \
#     spec/docs_screenshots/better_together/short_links_spec.rb
#
# Assets land in docs/screenshots/{desktop,mobile}/short_links_*.{png,json,narrative.yml}
#
# See skills/ce-pr-docs/SKILL.md for the full PR documentation workflow.

require 'rails_helper'

RSpec.describe 'Documentation screenshots for Short Links',
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let!(:manager) { find_or_create_test_user('manager@example.test', 'SecureTest123!@#', :platform_manager) }
  let!(:host_platform) do
    configure_host_platform.tap do |platform|
      platform.update!(privacy: 'public', requires_invitation: false, allow_membership_requests: false)
    end
  end
  let!(:active_short_link) do
    BetterTogether::ShortLink.create!(
      code: 'abc123',
      target_url: 'https://bettertogethersolutions.com/',
      title: 'BTS Homepage',
      status: :active,
      platform: host_platform,
      creator: manager.person
    )
  end
  let!(:expired_short_link) do
    BetterTogether::ShortLink.create!(
      code: 'exp999',
      target_url: 'https://example.com/old-page',
      title: 'Expired Link',
      status: :active,
      expires_at: 2.days.ago,
      platform: host_platform,
      creator: manager.person
    )
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
  end

  after do
    Current.platform = nil
  end

  def screenshot_metadata(flow:, role:)
    {
      locale: I18n.default_locale,
      role:,
      feature_set: 'short_links',
      flow:,
      source_spec: self.class.metadata[:file_path]
    }
  end

  it 'captures the short links index — populated list' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'short_links_index_default',
      device: :both,
      metadata: screenshot_metadata(flow: 'short_links_index', role: 'platform_manager'),
      callouts: [
        {
          id: 'copy_button',
          selector: '#short-links-table tbody tr:first-child [data-better_together--clipboard-target="button"]',
          title: 'Copy short URL',
          bullets: [
            'Copies the short URL to the clipboard.',
            'Icon flips to a checkmark for 2 seconds as confirmation.'
          ]
        },
        {
          id: 'status_badge',
          selector: '#short-links-table .short-link-status-badge.bg-success',
          title: 'Active status badge',
          bullets: [
            'Green = active and unexpired.',
            'Yellow = scheduled or inactive.',
            'Grey = expired.'
          ]
        },
        {
          id: 'new_button',
          selector: '#new-short-link-btn',
          title: 'New Short Link',
          bullets: ['Opens the form to create a new short link for any URL.']
        }
      ],
      narrative: {
        title: 'Short Links — Index Page',
        audience: %w[platform_manager developer],
        journey_step: 'As a platform manager, I view the short links list to find, copy, and manage all share URLs on my platform.',
        callouts: [
          {
            id: 'copy_button',
            title: 'Copy short URL',
            description: 'One click copies the full short URL to the clipboard. ' \
                         'The icon briefly changes to a checkmark to confirm the copy succeeded.'
          },
          {
            id: 'status_badge',
            title: 'Status badge',
            description: 'Shows whether each link is active, inactive, or expired. Green = safe to share, grey = no longer redirecting.'
          },
          {
            id: 'new_button',
            title: 'New Short Link',
            description: 'Opens the creation form for a new short link pointing to any target URL.'
          }
        ],
        accessibility_notes: 'All action buttons (view, edit, delete, copy) have aria-label attributes. Decorative icons are aria-hidden.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.short_links_path(locale: I18n.default_locale)
      expect(page).to have_css('table')
      expect(page).to have_text('abc123')
    end
  end

  it 'captures the short links index — empty state' do
    active_short_link.destroy!
    expired_short_link.destroy!

    BetterTogether::CapybaraScreenshotEngine.capture(
      'short_links_index_empty',
      device: :both,
      metadata: screenshot_metadata(flow: 'short_links_index_empty', role: 'platform_manager'),
      narrative: {
        title: 'Short Links — Empty State',
        audience: %w[platform_manager developer],
        journey_step: 'As a platform manager, I see the empty state before any short links have been created.',
        callouts: [],
        accessibility_notes: 'Empty state uses semantic paragraph text with no missing landmark regions.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.short_links_path(locale: I18n.default_locale)
      expect(page).to have_text('No short links yet')
    end
  end

  it 'captures the short link detail page — active link' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'short_links_show_default',
      device: :both,
      metadata: screenshot_metadata(flow: 'short_links_show', role: 'platform_manager'),
      callouts: [
        {
          id: 'short_url_input',
          selector: '#short-link-url',
          title: 'Short URL',
          bullets: [
            'Read-only field showing the full short URL.',
            'Click the copy button on the right to copy it instantly.'
          ]
        },
        {
          id: 'click_count',
          selector: '#short-link-click-count',
          title: 'Click count',
          bullets: ['Total number of times this link has been followed.']
        }
      ],
      narrative: {
        title: 'Short Link — Detail Page',
        audience: %w[platform_manager developer],
        journey_step: 'As a platform manager, I view a short link detail page to see ' \
                      'its target URL, click count, and status, and copy the short URL.',
        callouts: [
          {
            id: 'short_url_input',
            title: 'Short URL field',
            description: 'Read-only input showing the full short URL. The adjacent copy button ' \
                         'uses the Stimulus clipboard controller — click counts are tracked ' \
                         'in the browser, not server-side.'
          },
          {
            id: 'click_count',
            title: 'Click count',
            description: 'Server-side counter incremented on every redirect. Useful for gauging link popularity.'
          }
        ],
        accessibility_notes: 'Input has id matching label for= attribute. Copy button has aria-label. Status icons are aria-hidden.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.short_link_path(active_short_link, locale: I18n.default_locale)
      expect(page).to have_field('short-link-url')
    end
  end

  it 'captures the share button on a page — short URL clipboard integration' do
    page_record = create(:better_together_page, :published_public, platform: host_platform)
    create(:better_together_short_link,
           platform: host_platform,
           linkable: page_record,
           target_url: 'https://bettertogethersolutions.com/',
           status: 'active',
           expires_at: nil)

    BetterTogether::CapybaraScreenshotEngine.capture(
      'short_links_share_button',
      device: :both,
      metadata: screenshot_metadata(flow: 'short_links_share_button', role: 'user'),
      callouts: [
        {
          id: 'share_link_button',
          selector: '[data-better_together--clipboard-url-value]',
          title: 'Share link button',
          bullets: [
            'Appears in the share panel on any Shortlinkable content.',
            'Clicking copies the short URL to clipboard — no page reload required.'
          ]
        }
      ],
      narrative: {
        title: 'Share Panel — Short URL Button',
        audience: %w[admin developer content_editor end_user],
        journey_step: 'As a visitor, I click the share link icon on a page to instantly copy the short URL to my clipboard.',
        callouts: [
          {
            id: 'share_link_button',
            title: 'Short URL clipboard button',
            description: 'Copies the platform-scoped short URL to the clipboard. ' \
                         'The icon briefly shows a checkmark to confirm success. ' \
                         'Works for any Shortlinkable model (pages, posts, events).'
          }
        ],
        accessibility_notes: 'Button has aria-label and title. Stack icon layers are aria-hidden.'
      }
    ) do
      visit better_together.render_page_path(page_record.slug, locale: I18n.default_locale)
      expect(page).to have_css('[data-better_together--clipboard-url-value]')
    end
  end
end
