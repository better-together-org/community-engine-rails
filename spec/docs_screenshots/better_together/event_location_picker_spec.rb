# frozen_string_literal: true

# Capture command (run from repo root):
#   RUN_DOCS_SCREENSHOTS=1 bin/dc-run bundle exec prspec \
#     spec/docs_screenshots/better_together/event_location_picker_spec.rb
#
# Assets land in docs/screenshots/{desktop,mobile}/event_location_*.{png,json,narrative.yml}
#
# See skills/ce-pr-docs/SKILL.md for the full PR documentation workflow.

require 'rails_helper'

RSpec.describe 'Documentation screenshots for the event location picker',
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let(:manager) { find_or_create_test_user('manager@example.test', 'SecureTest123!@#', :platform_manager) }
  let(:host_platform) do
    configure_host_platform.tap do |platform|
      platform.update!(privacy: 'public', requires_invitation: false, allow_membership_requests: false)
    end
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
      feature_set: 'event_location_picker',
      flow:,
      source_spec: self.class.metadata[:file_path]
    }
  end

  def open_time_and_place_tab
    find('#event-time-and-place-tab').click
    expect(page).to have_css('#event-time-and-place.show')
  end

  it 'captures the location type selector on a new event' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'event_location_type_selector',
      device: :both,
      metadata: screenshot_metadata(flow: 'event_location_type_selector', role: 'event_organizer'),
      callouts: [
        {
          id: 'type_selector',
          selector: '[data-better_together--location-selector-target="typeSelector"]',
          title: 'Location type',
          bullets: [
            'Simple: free-text name only (original behavior, still the default).',
            'Address / Building / Settlement / Region: attach a real, existing record.'
          ]
        }
      ],
      narrative: {
        title: 'Event Form — Location Type Selector',
        audience: %w[event_organizer community_organizer developer],
        journey_step: 'As an event organizer, I choose how precisely to describe where my event ' \
                      'takes place — a plain name, or a real address/building/settlement/region ' \
                      'already known to the platform.',
        callouts: [
          {
            id: 'type_selector',
            title: 'Location type radio group',
            description: 'New in this PR: Settlement and Region join the existing Address and ' \
                         'Building options. The allow-list is read from ' \
                         'BetterTogether::Geography::Placeable.included_in_models on the server, ' \
                         'so a future fifth location type appears here automatically with no view change.'
          }
        ],
        accessibility_notes: 'Each radio has an associated <label for=""> and the group is a role="group" ' \
                             'button toolbar; screen readers announce the currently selected type.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.new_event_path(locale: I18n.default_locale)
      open_time_and_place_tab

      expect(page).to have_css('[data-better_together--location-selector-target="typeSelector"]')
    end
  end

  it 'captures an event with an existing settlement already assigned' do
    settlement = create(:geography_settlement, name: 'Corner Brook')
    event = create(:better_together_event, platform: host_platform, creator: manager.person,
                                           name: 'Community Meetup')
    event.create_location!(location: settlement, location_type: 'BetterTogether::Geography::Settlement')

    BetterTogether::CapybaraScreenshotEngine.capture(
      'event_location_settlement_assigned',
      device: :both,
      metadata: screenshot_metadata(flow: 'event_location_settlement_assigned', role: 'event_organizer'),
      # No callout box here: selecting the settlement radio on connect()
      # destroys and rebuilds the SlimSelect widget to point it at the
      # settlement AJAX source, and that rebuild can still be settling at the
      # exact moment the callout engine's synchronous querySelector runs —
      # an annotation-timing quirk in the SlimSelect/Capybara integration, not
      # a bug in the feature itself (confirmed correct via direct DOM
      # inspection: the field and its assigned value both render correctly).
      # The narrative below still documents what the screenshot shows.
      narrative: {
        title: 'Event Form — Settlement Already Assigned',
        audience: %w[event_organizer community_organizer platform_organizer developer],
        journey_step: 'As an event organizer editing an existing event, I see which settlement is ' \
                      'currently assigned and can search for a different one without leaving the form.',
        callouts: [
          {
            id: 'location_select',
            title: 'AJAX-backed location search',
            description: 'Genuinely new capability in this PR: this single field works for all four ' \
                         'structured types. Selecting the radio above rewrites this field\'s search ' \
                         'source — Address and Building searches are scoped to records the organizer ' \
                         'is allowed to use; Settlement and Region search the full curated reference list.'
          }
        ],
        accessibility_notes: 'The search combobox is keyboard-operable (type-ahead, arrow keys, Enter to ' \
                             'select) and exposes role="combobox" to assistive technology.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.edit_event_path(event, locale: I18n.default_locale)
      open_time_and_place_tab

      # Selecting the settlement radio on connect() reinitializes SlimSelect
      # (destroy + rebuild) to point it at the settlement AJAX source. Wait for
      # that churn to settle — evidenced by the assigned settlement's name
      # actually appearing in the rebuilt widget — before the callout engine's
      # synchronous querySelector runs, or it can catch the brief in-between
      # state where the old widget was torn down and the new one isn't
      # attached yet.
      expect(page).to have_css('.location-fields .ss-main', text: settlement.name, wait: 5)
    end
  end

  it 'captures the inline "add a new address" panel' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'event_location_address_new_panel',
      device: :both,
      metadata: screenshot_metadata(flow: 'event_location_address_new_panel', role: 'event_organizer'),
      # Single callout only: declaring both the button and the panel hit an
      # annotation-timing edge case where the placement engine dropped one of
      # the two boxes regardless of declaration order. The panel is the more
      # informative target — its bounds also visually include the button
      # above it in these desktop/mobile widths.
      callouts: [
        {
          id: 'new_address_panel',
          selector: '[data-better_together--location-selector-target="newAddress"]',
          title: 'Inline address fields',
          bullets: [
            'Revealed by the "+ New" link next to the search field.',
            'The new address is saved together with the event in a single submit.'
          ]
        }
      ],
      narrative: {
        title: 'Event Form — Create a New Address Inline',
        audience: %w[event_organizer community_organizer developer],
        journey_step: 'As an event organizer, if the venue address isn\'t in the system yet, I add it ' \
                      'right here instead of being sent to a separate address-management screen first.',
        callouts: [
          {
            id: 'new_address_button',
            title: '"+ New" trigger',
            description: 'Only shown when the organizer has permission to create addresses ' \
                         '(Pundit-gated). Settlement and Region have no equivalent button — they are ' \
                         'curated reference data, chosen from the existing list only, never created here.'
          },
          {
            id: 'new_address_panel',
            title: 'Inline creation fields',
            description: 'Bug fixed in this PR: the "Label" dropdown (Main/Work/Other) previously ' \
                         'failed to save correctly and silently blocked every submission with a ' \
                         '"Label can\'t be blank" error. That is now fixed and covered by model specs.'
          }
        ],
        accessibility_notes: 'The "+ New" control is a real link with visible focus state; the revealed ' \
                             'panel receives programmatic focus on its first field when opened.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.new_event_path(locale: I18n.default_locale)
      open_time_and_place_tab

      find('label[for="address_location"]', visible: :all).click
      expect(page).to have_css('.location-fields .ss-main')

      within('[data-better_together--location-selector-target="structuredLocation"]') do
        find('a.btn', text: I18n.t('better_together.events.actions.create_new_short', default: 'New'),
                      match: :first).click
      end

      panel = find('[data-better_together--location-selector-target="newAddress"]', visible: true)
      # The revealed panel's own fields (label, privacy, physical/postal,
      # line1..country) push it below the fold — scroll it into view or its
      # bounding rect falls outside the captured image and the callout is
      # silently dropped (clip_rect rejects any target with zero on-screen
      # height/width after clipping to image bounds).
      page.scroll_to(panel, align: :center)
    end
  end
end
