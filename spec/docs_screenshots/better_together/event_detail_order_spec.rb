# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for the event detail order', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers
  include ActionView::RecordIdentifier

  let(:host_platform) do
    configure_host_platform.tap do |platform|
      platform.update!(privacy: 'public', requires_invitation: false, allow_membership_requests: false)
    end
  end
  let!(:event) do
    create(:better_together_event, :with_simple_location, name: 'Harbour Lights Concert', platform: host_platform,
                                                          privacy: 'public', starts_at: 3.days.from_now,
                                                          ends_at: 3.days.from_now + 2.hours,
                                                          registration_url: 'https://tickets.example.test/harbour')
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
  end

  after { Current.platform = nil }

  def metadata(flow)
    { locale: I18n.default_locale, role: 'platform_manager', feature_set: 'event_detail_order', flow:,
      source_spec: self.class.metadata[:file_path] }
  end

  def narrative(title, step)
    { title:, audience: %w[member developer], journey_step: step,
      callouts: [{ id: 'order', title: 'Date and time, then location',
                   description: 'The same order is used in the header, the About pane and the card.' }],
      accessibility_notes: 'Order in the DOM matches the visual order.' }
  end

  def order_callout(selector)
    { id: 'order', selector:, title: 'Date and time, then location',
      bullets: ['Date and time first.', 'Location below it.'] }
  end

  it 'captures the event card' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'event_detail_order_card', device: :both, metadata: metadata('event_detail_order_card'),
                                 callouts: [order_callout("##{dom_id(event)} .event-location")],
                                 narrative: narrative('Event card order', 'As a reader of the list, I see when, then where.')
    ) do
      capybara_login_as_platform_manager
      visit better_together.events_path(locale: I18n.default_locale)
      expect(page).to have_css('.event-card .event-location')
    end
  end

  it 'captures the event page' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'event_detail_order_show', device: :both, metadata: metadata('event_detail_order_show'),
                                 callouts: [order_callout('.event-info-container .event-datetime, .event-info-container .event-location')],
                                 narrative: narrative('Event page order', 'As a reader of an event, I see register, when, then where.')
    ) do
      visit better_together.event_path(event, locale: I18n.default_locale)
      expect(page).to have_css('#about .event-location')
    end
  end

  it 'captures the unannotated event card' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'event_detail_order_card_plain', device: :both, metadata: metadata('event_detail_order_card_plain')
    ) do
      visit better_together.events_path(locale: I18n.default_locale)
      expect(page).to have_css('.event-location')
      scroll_to(find('.event-card .event-location', match: :first), align: :center)
    end
  end

  it 'captures the unannotated event page' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'event_detail_order_show_plain', device: :both, metadata: metadata('event_detail_order_show_plain')
    ) do
      visit better_together.event_path(event, locale: I18n.default_locale)
      expect(page).to have_css('.event-location')
      scroll_to(find('#about .event-location', match: :first), align: :center)
    end
  end
end
