# frozen_string_literal: true

require 'rails_helper'

# Capture command (run from repo root):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 bundle exec prspec \
#     spec/docs_screenshots/better_together/community_marks_spec.rb'
RSpec.describe 'Documentation screenshots for community marks', # rubocop:disable RSpec/SpecFilePathSuffix
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
    create(:community, name: 'Harbour Arts Collective', privacy: 'public', creator: manager.person).tap do |record|
      record.logo.attach(io: File.open(images.join('better-together-logo-centered-1500x430px.png')),
                         filename: 'logo.png', content_type: 'image/png')
    end
  end
  let(:event) do
    create(:better_together_event, name: 'Harbour Arts Night', privacy: 'public', platform: host_platform,
                                   creator: manager.person, starts_at: 3.days.from_now,
                                   ends_at: 3.days.from_now + 2.hours,
                                   event_hosts_attributes: [{ host_type: 'BetterTogether::Community',
                                                              host_id: community.id }])
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
  end

  after { Current.platform = nil }

  def metadata(flow)
    { locale:, role: 'platform_manager', feature_set: 'community_marks', flow:,
      source_spec: self.class.metadata[:file_path] }
  end

  def attach_cover
    community.cover_image.attach(io: File.open(images.join('unsplash-community-1.jpeg')),
                                 filename: 'cover.jpg', content_type: 'image/jpeg')
  end

  def scroll_to(selector)
    page.execute_script("document.querySelector('#{selector}').scrollIntoView({block: 'center'})")
  end

  def capture(name, selector:, title:, bullet:, &)
    BetterTogether::CapybaraScreenshotEngine.capture(
      name, device: :both, metadata: metadata(name),
            callouts: [{ id: 'mark', selector:, title:, bullets: [bullet] }],
            narrative: { title:, audience: %w[community_member developer],
                         journey_step: "As a visitor, I recognise a community by its logo: #{title.downcase}.",
                         callouts: [{ id: 'mark', title:, description: bullet }],
                         accessibility_notes: 'Decorative marks have empty alt text; names stay in text.' },
      &
    )
  end

  it 'captures the logo on a community card' do
    attach_cover
    capture('community_marks_card', selector: '.community-card-mark', title: 'Card mark',
                                    bullet: 'The logo, else the profile image, over the cover.') do
      visit better_together.communities_path(locale:)
      expect(page).to have_css('.community-card-mark')
      scroll_to('.community-card-mark')
    end
  end

  it 'captures the plain community card' do
    attach_cover
    BetterTogether::CapybaraScreenshotEngine.capture(
      'community_marks_card_plain', device: :both, metadata: metadata('card_plain')
    ) do
      visit better_together.communities_path(locale:)
      expect(page).to have_css('.community-card-mark')
      scroll_to('.community-card-mark')
    end
  end

  it 'captures the host mention on an event card' do
    event
    capture('community_marks_host', selector: '.event-host .community-mark-tile', title: 'Host mark',
                                    bullet: 'A hosting community shows its logo as a tile.') do
      visit better_together.events_path(locale:)
      expect(page).to have_css('.event-host .community-mark-tile')
      scroll_to('.event-host .community-mark-tile')
    end
  end

  it 'captures the plain host mention' do
    event
    BetterTogether::CapybaraScreenshotEngine.capture(
      'community_marks_host_plain', device: :both, metadata: metadata('host_plain')
    ) do
      visit better_together.events_path(locale:)
      expect(page).to have_css('.event-host .community-mark-tile')
      scroll_to('.event-host .community-mark-tile')
    end
  end

  it 'captures the community chip on a post card' do
    create(:better_together_post, community:, privacy: 'public', published_at: 1.day.ago, creator: manager.person)
    capture('community_marks_chip', selector: '.community-chip', title: 'Chip mark',
                                    bullet: 'The chip uses the same mark as cards and hosts.') do
      visit better_together.posts_path(locale:)
      expect(page).to have_css('.community-chip .community-mark-tile')
      scroll_to('.community-chip')
    end
  end

  it 'captures the plain community chip' do
    create(:better_together_post, community:, privacy: 'public', published_at: 1.day.ago, creator: manager.person)
    BetterTogether::CapybaraScreenshotEngine.capture(
      'community_marks_chip_plain', device: :both, metadata: metadata('chip_plain')
    ) do
      visit better_together.posts_path(locale:)
      expect(page).to have_css('.community-chip .community-mark-tile')
      scroll_to('.community-chip')
    end
  end
end
