# frozen_string_literal: true

require 'rails_helper'

# Capture command (run from repo root):
#   RUN_DOCS_SCREENSHOTS=1 bin/dc-run bundle exec prspec \
#     spec/docs_screenshots/better_together/events_index_filter_spec.rb
RSpec.describe 'Documentation screenshots for events index filters', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let(:locale) { I18n.default_locale }
  let(:host_platform) do
    configure_host_platform.tap do |platform|
      platform.update!(privacy: 'public', host_url: 'http://www.example.com')
    end
  end
  let(:manager) { find_or_create_test_user('manager@example.test', 'SecureTest123!@#', :platform_manager) }
  let(:creator) { create(:better_together_person, name: 'Harbour Events Team') }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
  end

  after do
    Current.platform = nil
  end

  def seed_events # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    workshops = create(:event_category, name: 'Workshops')
    gatherings = create(:event_category, name: 'Community Gatherings')

    yoga = create(:event, platform: host_platform, creator:, name: 'Sunrise Yoga in Bannerman Park',
                          starts_at: 3.days.from_now, ends_at: 3.days.from_now + 2.hours)
    potluck = create(:event, platform: host_platform, creator:, name: 'Community Potluck at the Hall',
                             starts_at: 5.days.from_now, ends_at: 5.days.from_now + 3.hours)
    create(:categorization, categorizable: yoga, category: workshops)
    create(:categorization, categorizable: potluck, category: gatherings)

    create(:event, platform: host_platform, creator:, name: 'Cancelled Shoreline Cleanup',
                   status: 'cancelled', starts_at: 2.days.from_now, ends_at: 2.days.from_now + 2.hours)
    create(:event, platform: host_platform, creator: manager.person, name: 'Draft Winter Market Planning',
                   status: 'draft', starts_at: 2.weeks.from_now, ends_at: 2.weeks.from_now + 2.hours)

    create_list(:event, 22, platform: host_platform, creator:)
  end

  it 'captures the default filtered index (desktop)' do
    seed_events

    BetterTogether::CapybaraScreenshotEngine.capture(
      'events_index_filters',
      device: :desktop,
      metadata: docs_metadata(flow: 'events_index_default'),
      callouts: [
        {
          id: 'new_event_btn',
          selector: '#new-event-btn',
          title: 'Add New Event',
          bullets: ['Shown only to people who can create events (policy-gated).']
        },
        {
          id: 'filter_sidebar',
          selector: '#events-filter-sidebar',
          title: 'Filter sidebar',
          bullets: [
            'Text search over event name + description (ILIKE, locale-aware).',
            'Category multi-select, status (All/Draft/Confirmed/Cancelled),',
            'order (Soonest/Latest/Newest/Oldest), per-page (10/20/50), past-events toggle.'
          ]
        },
        {
          id: 'result_count',
          selector: '#events-result-count',
          title: 'Result count',
          bullets: ['Total matching events across all pages (Kaminari total_count).']
        },
        {
          id: 'pagination',
          selector: '#events-pagination',
          title: 'Pagination',
          bullets: ['Default 20 per page; rendered above and below the results.']
        }
      ],
      narrative: {
        title: 'Events Index — unified search, filter, and pagination',
        audience: %w[community_member event_organizer platform_manager developer],
        journey_step: 'As a community member, I browse upcoming events soonest-first and narrow them ' \
                      'by search text, category, or status.',
        callouts: [
          { id: 'new_event_btn', title: 'Add New Event',
            description: 'Create CTA plus the publishing agreement notice, both policy-gated.' },
          { id: 'filter_sidebar', title: 'Filter sidebar',
            description: 'Replaces the old fixed Draft/Upcoming/Ongoing/Past sections with a single ' \
                         'bookmarkable GET form. Default view: upcoming events, soonest-first.' },
          { id: 'result_count', title: 'Result count',
            description: 'Shows how many events match the active filters.' },
          { id: 'pagination', title: 'Pagination',
            description: 'Kaminari pagination with 10/20/50 per-page options.' }
        ],
        accessibility_notes: 'All filter controls have visible labels; the mobile toggle is a real ' \
                             'button with aria-expanded/aria-controls; status badges are text, not color-only.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.events_path(locale:)

      expect(page).to have_css('#events .event-card')
      expect(page).to have_css('#events-pagination')
    end
  end

  it 'captures the draft status filter (desktop)' do
    seed_events

    BetterTogether::CapybaraScreenshotEngine.capture(
      'events_index_status_draft',
      device: :desktop,
      metadata: docs_metadata(flow: 'events_index_status_filter'),
      callouts: [
        {
          id: 'status_select',
          selector: '#events-status',
          title: 'Status filter',
          bullets: [
            'Filters by the new events.status enum (draft/confirmed/cancelled).',
            'Drafts are only visible to their creator, hosts, invitees, or platform event managers.'
          ]
        },
        {
          id: 'clear_filters',
          selector: '#events-clear-filters',
          title: 'Clear Filters',
          bullets: ['Returns to the default view: upcoming events, soonest-first, 20 per page.']
        },
        {
          id: 'status_badge',
          selector: '#events .event-status-badge',
          title: 'Status badge',
          bullets: ['Non-confirmed events carry a localized Draft/Cancelled badge on their card.']
        }
      ],
      narrative: {
        title: 'Events Index — draft status filter',
        audience: %w[event_organizer platform_manager developer],
        journey_step: 'As an organizer, I filter to my draft events to keep working on them before ' \
                      'confirming.',
        callouts: [
          { id: 'status_select', title: 'Status filter',
            description: 'Single value via the select; the controller also accepts status[] arrays ' \
                         'for unions (e.g. draft + confirmed).' },
          { id: 'clear_filters', title: 'Clear Filters', description: 'Resets all filters to defaults.' },
          { id: 'status_badge', title: 'Status badge',
            description: 'Replaces the old hardcoded DRAFT marker that keyed off a missing start time.' }
        ],
        accessibility_notes: 'Status select has an explicit label; badge text is localized.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.events_path(locale:, status: 'draft')

      expect(page).to have_text('Draft Winter Market Planning')
      expect(page).to have_css('#events .event-status-badge')
    end
  end

  it 'captures the collapsed mobile sidebar' do
    seed_events

    BetterTogether::CapybaraScreenshotEngine.capture(
      'events_index_mobile',
      device: :mobile,
      metadata: docs_metadata(flow: 'events_index_mobile'),
      callouts: [
        {
          id: 'filter_toggle',
          selector: '#events-filter-toggle',
          title: 'Filters toggle',
          bullets: ['Below the lg breakpoint the sidebar collapses behind this Bootstrap toggle.']
        }
      ],
      narrative: {
        title: 'Events Index — mobile collapsed filters',
        audience: %w[community_member developer],
        journey_step: 'As a mobile visitor, I expand the filters only when I need them, keeping the ' \
                      'event list front and centre.',
        callouts: [
          { id: 'filter_toggle', title: 'Filters toggle',
            description: 'aria-expanded/aria-controls wired to the #events-filter-sidebar collapse.' }
        ],
        accessibility_notes: 'Toggle is a native button; collapse state is exposed via aria-expanded.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.events_path(locale:)

      expect(page).to have_css('#events-filter-toggle')
    end
  end

  private

  def docs_metadata(flow:)
    {
      locale:,
      role: 'platform_manager',
      feature_set: 'events_index_filters',
      flow:,
      source_spec: self.class.metadata[:file_path]
    }
  end
end
