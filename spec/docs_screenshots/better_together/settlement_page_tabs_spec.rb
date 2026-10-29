# frozen_string_literal: true

require 'rails_helper'

# Capture command (run from repo root):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 bundle exec prspec \
#     spec/docs_screenshots/better_together/settlement_page_tabs_spec.rb'
RSpec.describe 'Documentation screenshots for the settlement pages', # rubocop:disable RSpec/SpecFilePathSuffix
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
  let(:settlement) do
    create(:geography_settlement, name: 'Harbour Cove', identifier: 'harbour-cove',
                                  description: 'A fishing village on the northern shore.')
  end
  let(:elsewhere) { create(:geography_settlement, name: 'Hilltop', identifier: 'hilltop') }
  let(:community) do
    create(:better_together_community, name: 'Harbour Arts Collective', privacy: 'public', creator: manager.person)
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    community.create_location!(location: settlement)
    create(:better_together_post, :public, :published, title: 'Harbour Notes', community:)
    create(:better_together_post, :public, :published, title: 'Hilltop Notes',
                                                       community: create(:better_together_community, privacy: 'public')
                                                                  .tap { |c| c.create_location!(location: elsewhere) })
    event = create(:better_together_event, name: 'Harbour Festival', platform: host_platform,
                                           starts_at: 2.days.from_now, ends_at: 2.days.from_now + 2.hours)
    event.create_location!(location: settlement)
  end

  after { Current.platform = nil }

  def metadata(flow)
    { locale:, role: 'platform_manager', feature_set: 'settlement_page_tabs', flow:,
      source_spec: self.class.metadata[:file_path] }
  end

  def visit_settlement
    capybara_login_as_platform_manager
    visit better_together.geography_settlement_path(locale:, id: settlement.slug)
    expect(page).to have_css('#settlement-tabbed-section')
  end

  def open_tab(name)
    find("##{name}-tab").click
    scroll_to(find('#settlement-tabbed-section'), align: :top)
  end

  it 'captures the settlements index with its gloss' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'settlement_pages_index', device: :both, metadata: metadata('index'),
                                callouts: [
                                  { id: 'gloss', selector: '#settlements-description', title: 'What a settlement is',
                                    avoid_selectors: ['#settlements-table'],
                                    bullets: ['One line under the heading; translated per locale.',
                                              'The table below is described by it for assistive technology.'] }
                                ],
                                narrative: {
                                  title: 'Settlements index',
                                  audience: %w[community_member developer],
                                  journey_step: 'As a visitor, I learn what counts as a settlement before browsing.',
                                  callouts: [
                                    { id: 'gloss', title: 'What a settlement is',
                                      description: 'Cities, towns, villages, hamlets, First Nations communities and ' \
                                                   'other named places. The table points at it with aria-describedby.' }
                                  ],
                                  accessibility_notes: 'The table is described by the gloss paragraph.'
                                }
    ) do
      capybara_login_as_platform_manager
      settlement
      visit better_together.geography_settlements_path(locale:)
      expect(page).to have_css('#settlements-table')
      scroll_to(find('#settlements-description'), align: :center)
    end
  end

  it 'captures the plain settlements index' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'settlement_pages_index_plain', device: :both, metadata: metadata('index_plain')
    ) do
      capybara_login_as_platform_manager
      settlement
      visit better_together.geography_settlements_path(locale:)
      expect(page).to have_css('#settlements-table')
    end
  end

  it 'captures the settlement page tabs' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'settlement_pages_show_tabs', device: :both, metadata: metadata('tabs'),
                                    callouts: [
                                      { id: 'tabs', selector: '#geography-settlement', title: 'Tabs',
                                        avoid_container_selector: '#settlement-tabbed-section',
                                        bullets: ['About, Posts, Events, plus Communities when any are located here.',
                                                  'Named for assistive technology with a translated aria-label.'] }
                                    ],
                                    narrative: {
                                      title: 'Settlement page tabs',
                                      audience: %w[community_member developer],
                                      journey_step: 'As a visitor, I see what is happening in a settlement.',
                                      callouts: [
                                        { id: 'tabs', title: 'Tabs',
                                          description: 'Host apps add tabs through the tab_links_extra and ' \
                                                       'tab_panes_extra hook partials.' }
                                      ],
                                      accessibility_notes: 'role=tablist with aria-controls and aria-labelledby pairs.'
                                    }
    ) do
      visit_settlement
      expect(page).to have_css('#communities-tab')
    end
  end

  it 'captures the plain settlement page' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'settlement_pages_show_tabs_plain', device: :both, metadata: metadata('tabs_plain')
    ) do
      visit_settlement
      expect(page).to have_css('#communities-tab')
    end
  end

  it 'captures the communities tab' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'settlement_pages_show_communities', device: :both, metadata: metadata('communities')
    ) do
      visit_settlement
      open_tab('communities')
      expect(page).to have_css('#settlement-communities', text: 'Harbour Arts Collective')
    end
  end

  it 'captures the posts tab with only this settlement posts' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'settlement_pages_show_posts', device: :both, metadata: metadata('posts')
    ) do
      visit_settlement
      open_tab('posts')
      expect(page).to have_css('#settlement-posts', text: 'Harbour Notes')
      expect(page).to have_no_text('Hilltop Notes')
    end
  end

  it 'captures the events tab with only this settlement events' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'settlement_pages_show_events', device: :both, metadata: metadata('events')
    ) do
      visit_settlement
      open_tab('events')
      expect(page).to have_css('#settlement-events', text: 'Harbour Festival')
    end
  end
end
