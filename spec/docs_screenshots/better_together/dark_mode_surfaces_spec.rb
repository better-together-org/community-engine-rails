# frozen_string_literal: true

# Capture command (run from repo root):
#   RUN_DOCS_SCREENSHOTS=1 WORKERS=3 bin/dc-run bundle exec prspec \
#     spec/docs_screenshots/better_together/dark_mode_surfaces_spec.rb
#
# Surfaces that used a fixed light background (bg-light, bg-white, btn-light), shown in light and dark mode on
# desktop and mobile, each as an annotated and a plain capture.

require 'rails_helper'

RSpec.describe 'Documentation screenshots for colour mode aware surfaces', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let(:manager) { find_or_create_test_user('manager@example.test', 'SecureTest123!@#', :platform_manager) }
  let(:host_platform) do
    configure_host_platform.tap { |platform| platform.update!(privacy: 'public', requires_invitation: false) }
  end
  let(:locale) { I18n.default_locale }
  let(:seed) { create(:better_together_seed, identifier: "dark-mode-seed-#{SecureRandom.hex(3)}") }
  let(:event) do
    create(:better_together_event, :upcoming).tap do |record|
      BetterTogether::EventHost.create!(event: record, host: create(:better_together_community))
    end
  end
  let(:conversation) do
    other = create(:better_together_person)
    create(:better_together_conversation, creator: manager.person).tap do |record|
      record.participants << other
      record.messages.create!(sender: other, content: 'A message from someone else')
      record.messages.create!(sender: manager.person, content: 'A message from me')
    end
  end
  let(:iframe_page) do
    create(:better_together_page, platform: host_platform, protected: false, privacy: 'public',
                                  published_at: 1.day.ago).tap do |record|
      record.page_blocks.create!(block: create(:content_iframe_block, iframe_url_en: 'https://blocked.example.test/form'),
                                 position: 0)
    end
  end
  let(:editor_page) do
    create(:better_together_page, platform: host_platform, protected: false, privacy: 'public',
                                  published_at: 1.day.ago)
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    manager
  end

  after { Current.platform = nil }

  # Each surface names the annotated element and its callout text.
  surfaces = {
    'seed_payload' => { target: 'pre.bg-body-tertiary', title: 'Origin and payload',
                        note: 'Code blocks use the tertiary surface and body text.' },
    'event_host_card' => { target: '#event-hosts .card.bg-body-tertiary', title: 'Host card',
                           note: 'The card follows the colour mode.' },
    'conversation_messages' => { target: '.message-bubble', title: 'Message bubbles',
                                 note: 'Bubbles use Bootstrap colour variables.' },
    'iframe_blocked_notice' => { target: '.iframe-block__notice', title: 'Blocked embed notice',
                                 note: 'The notice surface and text follow the mode.' },
    'block_picker' => { target: '#available-block-types', title: 'Block picker',
                        note: 'Tile and glyph invert with the mode.' },
    'platform_feature_gates' => { target: '#platform-features .card.bg-body-tertiary', title: 'Feature gates',
                                  note: 'Cards use body and tertiary surfaces.' }
  }.freeze

  define_method(:surface_target) { |key| surfaces.fetch(key)[:target] }

  def metadata(flow)
    { locale:, role: 'platform_manager', feature_set: 'dark_mode_surfaces', flow:,
      source_spec: self.class.metadata[:file_path] }
  end

  def open_surface(key) = send("open_#{key}")

  def open_seed_payload = visit(better_together.seed_path(seed.id, locale:))

  def open_conversation_messages = visit(better_together.conversation_path(conversation, locale:))

  def open_iframe_blocked_notice = visit(better_together.render_page_path(path: iframe_page.slug, locale:))

  def open_event_host_card
    visit better_together.edit_event_path(event, locale:)
    page.execute_script("document.querySelector('#event-hosts-tab').click()")
  end

  def open_block_picker
    visit better_together.edit_page_path(editor_page, locale:)
    expect(page).to have_css('#available-block-types', visible: :all, wait: 10)
    page.execute_script("document.querySelector('#available-block-types').classList.add('show')")
  end

  def open_platform_feature_gates
    visit better_together.edit_platform_path(host_platform, locale:)
    page.execute_script("document.querySelector('#platform-features-tab').click()")
  end

  def show_surface(key, mode)
    capybara_login_as_platform_manager
    open_surface(key)
    target = surface_target(key)
    expect(page).to have_css(target, wait: 10)
    page.execute_script("document.documentElement.setAttribute('data-bs-theme', '#{mode}')")
    scroll_to(first(target), align: :center)
    sleep 0.4
  end

  surfaces.each do |key, surface|
    %w[light dark].each do |mode|
      it "captures #{key} in #{mode} mode annotated" do # rubocop:disable RSpec/NoExpectationExample
        BetterTogether::CapybaraScreenshotEngine.capture(
          "dark_mode_#{key}_#{mode}", device: :both, metadata: metadata("dark_mode_#{key}_#{mode}"),
                                      callouts: [{ selector: surface[:target], title: "#{surface[:title]} (#{mode})",
                                                   bullets: [surface[:note]] }]
        ) { show_surface(key, mode) }
      end

      it "captures #{key} in #{mode} mode plain" do # rubocop:disable RSpec/NoExpectationExample
        BetterTogether::CapybaraScreenshotEngine.capture(
          "dark_mode_#{key}_#{mode}_plain", device: :both, metadata: metadata("dark_mode_#{key}_#{mode}_plain")
        ) { show_surface(key, mode) }
      end
    end
  end
end
