# frozen_string_literal: true

# Capture command (run from repo root):
#   RUN_DOCS_SCREENSHOTS=1 bin/dc-run bundle exec prspec \
#     spec/docs_screenshots/better_together/seed_catalog_spec.rb
#
# Assets land in docs/screenshots/{desktop,mobile}/seed_catalog_*.{png,json,narrative.yml}
#
# See skills/ce-pr-docs/SKILL.md for the full PR documentation workflow.

require 'rails_helper'

RSpec.describe 'Documentation screenshots for the geography seed catalog',
               :docs_screenshot,
               :js,
               :no_auth,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let(:host_platform) do
    configure_host_platform.tap do |platform|
      platform.update!(privacy: 'public', requires_invitation: false, allow_membership_requests: false)
    end
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    # :no_auth is required here (not just :skip_host_setup): the global
    # config.before(:each, type: :feature) hook in automatic_test_configuration.rb calls
    # setup_authentication_if_needed unconditionally -- it does NOT check :skip_host_setup --
    # and on a description that doesn't match any manager/user keyword it falls through to a
    # default "authenticate as regular user" path that calls find_or_create_test_user before
    # Current.platform is set below, which can fail Person validations on a fresh database with
    # no host platform yet. Each `it` block below performs its own explicit login, so the
    # implicit default-user login this hook would otherwise attempt is both unwanted and unsafe
    # here -- :no_auth suppresses it entirely.
    Current.platform = host_platform

    # bin/parallel-setup only fully drops+recreates the worktree's primary (unsuffixed) test DB;
    # the numbered parallel worker DBs (test2/3/4) are left as-is ("already exists") and can carry
    # planted geography rows over from an earlier run. This spec's "before anything has been
    # planted" / "after one category planted" scenarios depend on continents genuinely being
    # unplanted at the start, so clear explicitly rather than assuming worker-DB cleanliness.
    BetterTogether::GeographyBuilder.clear_existing
  end

  after do
    Current.platform = nil
  end

  def screenshot_metadata(flow:, role:)
    {
      locale: I18n.default_locale,
      role:,
      feature_set: 'seed_catalog',
      flow:,
      source_spec: self.class.metadata[:file_path]
    }
  end

  it 'captures the seed catalog before anything has been planted' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'seed_catalog_index_unplanted',
      device: :both,
      metadata: screenshot_metadata(flow: 'seed_catalog_index', role: 'platform_manager'),
      callouts: [
        {
          id: 'plant_all',
          selector: '#plant-all-geography-btn',
          title: 'Plant All',
          bullets: [
            'Installs every category in one action -- equivalent to GeographyBuilder.build_if_missing.',
            'Idempotent: safe to click even if some categories are already planted.'
          ]
        },
        {
          id: 'status_badge',
          selector: '.continents-status-badge',
          title: 'Category status',
          bullets: [
            'Grey "Not planted" before the category has any records.',
            'Coarse signal: checks for at least one record, not full seed-source coverage.'
          ]
        },
        {
          id: 'plant_button',
          selector: '#plant-continents-btn',
          title: 'Plant one category',
          bullets: [
            'Installs just this category via GeographyBuilder\'s existing seed_continents/seed_countries/etc.',
            'Packet-backed (lib/better_together/geography/seed_coordinates.yml): records land already ' \
            'geocoded, with zero live Nominatim calls in the common case.'
          ]
        },
        {
          id: 'missing_prerequisites',
          selector: '#plant-provinces-missing-prerequisites',
          title: 'Prerequisite-blocked category',
          bullets: [
            'New in this PR: Provinces requires Countries; Settlements requires Provinces.',
            'The Plant button for a category with an unmet prerequisite is disabled, with this hint ' \
            'explaining what to plant first.'
          ]
        }
      ],
      narrative: {
        title: 'Seed Catalog -- Nothing Planted',
        audience: %w[platform_manager developer],
        journey_step: 'As a platform manager, I open the seed catalog to install geography reference ' \
                      'data on my own schedule, instead of it being auto-seeded on every deploy.',
        callouts: [
          {
            id: 'plant_all',
            title: 'Plant All',
            description: 'One click installs Continents, Countries, Provinces & Territories, Regions, ' \
                         'and Settlements together, syncing the country<->continent and ' \
                         'region<->settlement join tables once both sides of each pair exist.'
          },
          {
            id: 'status_badge',
            title: 'Not planted',
            description: 'Every category starts unplanted -- this replaces the automatic ' \
                         'GeographyBuilder.build(clear: true) call that used to run on every seed/deploy.'
          },
          {
            id: 'plant_button',
            title: 'Plant one category',
            description: 'Category-level granularity, matching GeographyBuilder\'s existing separable ' \
                         'seed_continents/seed_countries/seed_provinces/seed_regions/seed_settlements methods.'
          },
          {
            id: 'missing_prerequisites',
            title: 'Prerequisite guard',
            description: 'Bug fixed in this PR: planting Settlements before Provinces (or Provinces ' \
                         'before Countries) previously raised an uncaught 500 -- seed_settlements looks ' \
                         'up its State by identifier and reads state.country, which is nil if Provinces ' \
                         'was never planted. GeographyCatalog.missing_prerequisites now checks this ' \
                         'server-side (returning a friendly alert instead of calling the builder method), ' \
                         'and the same check disables the button and shows this hint in the UI before the ' \
                         'organizer can even click it.'
          }
        ],
        accessibility_notes: 'Plant buttons carry an aria-label naming the specific category; the ' \
                             'disabled state (once planted, or once blocked on a missing prerequisite) is ' \
                             'a real disabled attribute, not just a CSS class.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.seed_catalog_seeds_path(locale: I18n.default_locale)

      expect(page).to have_css('#seed-catalog-geography-table')
      expect(page).to have_content('Not planted')
      expect(page).to have_css('#plant-provinces-btn[disabled]')
      expect(page).to have_css('#plant-provinces-missing-prerequisites')
    end
  end

  it 'captures the seed catalog after one category has been planted' do
    # Plant directly, once, before capture -- NOT inside the capture block below. `capture` with
    # device: :both invokes its block once per viewport (desktop, then mobile); a mutating click
    # inside that block would plant Continents on the first pass and then fail with
    # ElementClickInterceptedError on the second pass, since the button is correctly disabled once
    # planted. The click-through UI path is already covered by the DOM contract spec.
    BetterTogether::SeedCatalog::GeographyCatalog.plant(:continents)

    BetterTogether::CapybaraScreenshotEngine.capture(
      'seed_catalog_index_partially_planted',
      device: :both,
      metadata: screenshot_metadata(flow: 'seed_catalog_index', role: 'platform_manager'),
      callouts: [
        {
          id: 'planted_badge',
          selector: '.continents-status-badge',
          title: 'Planted',
          bullets: [
            'Green once the category has at least one record.',
            'The Plant button for this category becomes disabled -- clicking again is a no-op either way.'
          ]
        },
        {
          id: 'pending_badge',
          selector: '.countries-status-badge',
          title: 'Still not planted',
          bullets: [
            'Categories are independent -- planting Continents does not auto-plant Countries.',
            'The country<->continent join table only populates once both sides are planted.'
          ]
        }
      ],
      narrative: {
        title: 'Seed Catalog -- Partially Planted',
        audience: %w[platform_manager developer],
        journey_step: 'After planting Continents, I can see exactly which categories are installed ' \
                      'and which still need attention, before deciding whether to plant the rest.',
        callouts: [
          {
            id: 'planted_badge',
            title: 'Continents planted',
            description: 'GeographyCatalog.plant checks planted? before invoking the builder method, so ' \
                         'a raw repeat POST (bypassing the disabled button) cannot hit a duplicate-identifier error.'
          },
          {
            id: 'pending_badge',
            title: 'Countries not yet planted',
            description: 'Each category is planted independently via its own button, or all at once via Plant All.'
          }
        ],
        accessibility_notes: 'Status changes are reflected in both badge color and text, not color alone. ' \
                             'Provinces and Settlements are also visibly disabled with a hint at this ' \
                             'point (see the "nothing planted" screenshot above for the dedicated ' \
                             'prerequisite-guard callout) -- planting Continents alone does not unblock ' \
                             'either of them.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.seed_catalog_seeds_path(locale: I18n.default_locale)

      expect(page).to have_css('.continents-status-badge', text: 'Planted')
      expect(page).to have_css('.countries-status-badge', text: 'Not planted')
      expect(page).to have_css('#plant-provinces-btn[disabled]')
    end
  end

  it 'captures the Seed Catalog link on the Host Dashboard geography section' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'host_dashboard_seed_catalog_link',
      device: :both,
      metadata: screenshot_metadata(flow: 'host_dashboard_geography', role: 'platform_manager'),
      callouts: [
        {
          id: 'seed_catalog_link',
          selector: '#seed-catalog-link',
          title: 'Seed Catalog link',
          bullets: [
            'New in this PR -- the geography reference-data summary now links to the on-demand seed catalog.',
            'Previously the only way to install this data was a rake task, with no UI at all.'
          ]
        }
      ],
      narrative: {
        title: 'Host Dashboard -- Geography Section',
        audience: %w[platform_manager developer],
        journey_step: 'As a platform manager reviewing geography reference-data counts on the ' \
                      'dashboard, I can jump straight to the seed catalog to install what is missing.',
        callouts: [
          {
            id: 'seed_catalog_link',
            title: 'Seed Catalog link',
            description: 'Links to /host/seeds/catalog -- the same platform-manager gate as the rest of the host area.'
          }
        ],
        accessibility_notes: 'The link renders as a real anchor with visible text (not an icon-only ' \
                             'button), reachable by keyboard in normal tab order.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.host_dashboard_path(locale: I18n.default_locale)

      link = find('#seed-catalog-link', wait: 10)
      link.hover
      page.execute_script('arguments[0].scrollIntoView({block: "center"})', link)
      expect(page).to have_css('#seed-catalog-link')
    end
  end
end
