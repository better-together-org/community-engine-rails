# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for the event attendee list', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers
  include ActionView::RecordIdentifier

  let!(:organizer) { find_or_create_test_user('organizer@example.test', 'SecureTest123!@#', :user) }
  let(:host_platform) do
    configure_host_platform.tap do |platform|
      platform.update!(privacy: 'public', requires_invitation: false, allow_membership_requests: false)
    end
  end
  let!(:event) do
    create(:event, name: 'Harbour cleanup', platform: host_platform, creator: organizer.person, privacy: 'public')
  end
  let!(:friend) { create(:person, name: 'Ada Visible') }
  let!(:blocked) { create(:person, name: 'Blocked Person') }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    create(:event_attendance, event:, person: friend, status: 'going')
    create(:event_attendance, event:, person: blocked, status: 'going')
    create(:person_block, blocker: organizer.person, blocked:)
  end

  after { Current.platform = nil }

  def open_attendees_tab
    capybara_sign_in_user(organizer.email, 'SecureTest123!@#')
    visit better_together.event_path(event, locale: I18n.default_locale)
    find('#attendees-tab').click
    expect(page).to have_css('#event-attendees-list', text: 'Ada Visible')
    scroll_to(find('#event-attendees-list'), align: :center)
  end

  def metadata(flow)
    { locale: I18n.default_locale, role: 'event_organizer', feature_set: 'event_attendees_block_filter',
      flow:, source_spec: self.class.metadata[:file_path] }
  end

  it 'captures the annotated attendee list' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'event_attendees_block_filter',
      device: :both,
      metadata: metadata('event_attendees_block_filter'),
      callouts: [
        { id: 'attendee_list', selector: '#event-attendees-list', title: 'Attendee list',
          bullets: ['People you blocked, or who blocked you, are left out.'] }
      ],
      narrative: {
        title: 'Event attendees with block filtering',
        audience: %w[member organizer developer],
        journey_step: 'As an organizer, I do not see attendees I have blocked or who blocked me.',
        callouts: [
          { id: 'attendee_list', title: 'Attendee list',
            description: 'Blocked attendees are not listed and are not counted in the tab label.' }
        ],
        accessibility_notes: 'The list uses list-group items; names are plain text.'
      }
    ) do
      open_attendees_tab
      expect(page).to have_no_text('Blocked Person')
    end
  end

  it 'captures the unannotated attendee list' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'event_attendees_block_filter_plain',
      device: :both,
      metadata: metadata('event_attendees_block_filter_plain')
    ) do
      open_attendees_tab
      expect(page).to have_no_text('Blocked Person')
    end
  end
end
