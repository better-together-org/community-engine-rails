# frozen_string_literal: true

require 'rails_helper'

# Capture command (run from repo root):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 bundle exec prspec \
#     spec/docs_screenshots/better_together/community_show_hooks_spec.rb'
RSpec.describe 'Documentation screenshots for community page hooks', # rubocop:disable RSpec/SpecFilePathSuffix
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
  let(:images) { BetterTogether::Engine.root.join('app/assets/images/better_together') }
  let(:community) do
    create(:community, name: 'Harbour Arts Collective', privacy: 'public', creator: manager.person,
                       description: 'Artists working on the harbour.').tap do |record|
      record.cover_image.attach(io: File.open(images.join('unsplash-community-1.jpeg')),
                                filename: 'cover.jpg', content_type: 'image/jpeg')
      record.create_location!(location: create(:address), name: 'Harbour Hall')
    end
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    capybara_login_as_platform_manager
  end

  after { Current.platform = nil }

  def metadata(flow)
    { locale:, role: 'platform_manager', feature_set: 'community_show_hooks', flow:,
      source_spec: self.class.metadata[:file_path] }
  end

  def scroll_to(selector)
    page.execute_script("document.querySelector('#{selector}').scrollIntoView({block: 'center'})")
  end

  def capture(name, selector:, title:, bullet:, &)
    BetterTogether::CapybaraScreenshotEngine.capture(
      name, device: :both, metadata: metadata(name),
            callouts: [{ id: 'hook', selector:, title:, bullets: [bullet] }],
            narrative: { title:, audience: %w[community_member developer],
                         journey_step: "As a visitor, I open a community page: #{title.downcase}.",
                         callouts: [{ id: 'hook', title:, description: bullet }],
                         accessibility_notes: 'The default markup is unchanged; hooks only add override points.' },
      &
    )
  end

  def visit_community
    visit better_together.community_path(community, locale:)
    expect(page).to have_css("##{ActionView::RecordIdentifier.dom_id(community, :profile_header)}")
  end

  it 'captures the header media hook' do
    capture('community_show_hooks_header', selector: '.profile-header', title: 'Header media',
                                           bullet: 'The cover and profile image render through a partial a host can replace.') do
      visit_community
      expect(page).to have_css('.profile-header .cover-image-container')
      scroll_to('.profile-header')
    end
  end

  it 'captures the plain header' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'community_show_hooks_header_plain', device: :both, metadata: metadata('header_plain')
    ) do
      visit_community
      expect(page).to have_css('.profile-header .cover-image-container')
      scroll_to('.profile-header')
    end
  end

  it 'captures the location line hook' do
    capture('community_show_hooks_location', selector: '#community-location', title: 'Location line',
                                             bullet: 'The location line is its own partial; a host can link the place.') do
      visit_community
      expect(page).to have_css('#community-location')
      scroll_to('#community-location')
    end
  end

  it 'captures the plain location line' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'community_show_hooks_location_plain', device: :both, metadata: metadata('location_plain')
    ) do
      visit_community
      expect(page).to have_css('#community-location')
      scroll_to('#community-location')
    end
  end
end
