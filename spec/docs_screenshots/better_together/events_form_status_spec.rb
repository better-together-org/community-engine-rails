# frozen_string_literal: true

require 'rails_helper'

# Capture command (run from repo root):
#   bin/dc-run bash -c "RUN_DOCS_SCREENSHOTS=1 bundle exec prspec \
#     spec/docs_screenshots/better_together/events_form_status_spec.rb"
RSpec.describe 'Documentation screenshots for the event form status field', # rubocop:disable RSpec/SpecFilePathSuffix
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

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
  end

  after do
    Current.platform = nil
  end

  it 'captures the status select on the event edit form (desktop)' do
    grant_content_publishing_agreement(manager.person)
    event = create(:event, platform: host_platform, creator: manager.person,
                           name: 'Draft Winter Market Planning', status: 'draft',
                           starts_at: 2.weeks.from_now, ends_at: 2.weeks.from_now + 2.hours)

    BetterTogether::CapybaraScreenshotEngine.capture(
      'events_form_status',
      device: :desktop,
      metadata: {
        locale:,
        role: 'platform_manager',
        feature_set: 'events_index_filters',
        flow: 'events_form_status',
        source_spec: self.class.metadata[:file_path]
      },
      callouts: [
        {
          id: 'status_field',
          selector: '#event-status-field',
          title: 'Event status',
          bullets: [
            'New events start as Draft — visible only to the creator, co-hosts, and platform managers.',
            'Selecting Confirmed publishes the event to the events list; Cancelled marks it as called off.',
            'SlimSelect-enhanced, same pattern as the categories field.'
          ]
        }
      ],
      narrative: {
        title: 'Event form — explicit publish step via the status field',
        audience: %w[event_organizer platform_manager developer],
        journey_step: 'As an organizer, I keep my event as a draft while planning, then set it to ' \
                      'Confirmed when I am ready to publish it.',
        callouts: [
          { id: 'status_field', title: 'Event status',
            description: 'Backs the new events.status enum (default draft). Completes the ' \
                         'draft-by-default workflow: the index status filter and card badges read ' \
                         'the same column.' }
        ],
        accessibility_notes: 'Status select has an explicit label and a descriptive hint linked ' \
                             'below the control.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.edit_event_path(event, locale:)

      expect(page).to have_css('#event-status-field')
    end
  end
end
