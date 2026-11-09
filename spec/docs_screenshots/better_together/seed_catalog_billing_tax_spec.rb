# frozen_string_literal: true

# Capture command (run from repo root):
#   RUN_DOCS_SCREENSHOTS=1 bin/dc-run bundle exec prspec \
#     spec/docs_screenshots/better_together/seed_catalog_billing_tax_spec.rb
#
# Assets land in docs/screenshots/{desktop,mobile}/seed_catalog_billing_tax_*.{png,json,narrative.yml}
#
# See skills/ce-pr-docs/SKILL.md for the full PR documentation workflow.

require 'rails_helper'

# The expectations run inside the capture block.
# rubocop:disable RSpec/NoExpectationExample
RSpec.describe 'Documentation screenshots for the tax seed catalog',
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

    # :no_auth and the explicit login in each example: see seed_catalog_spec.rb for why.
    Current.platform = host_platform
    BetterTogether::Billing::TaxRate.where(platform_id: host_platform.id).delete_all
    host_platform.billing_tax_zones.delete_all
    host_platform.billing_tax_categories.delete_all
    BetterTogether::GeographyBuilder.clear_existing
  end

  after { Current.platform = nil }

  def screenshot_metadata(flow:)
    { locale: I18n.default_locale, role: 'platform_manager', feature_set: 'seed_catalog_billing_tax', flow:,
      source_spec: self.class.metadata[:file_path] }
  end

  def plant_geography
    BetterTogether::SeedCatalog::GeographyCatalog.plant(:countries)
    BetterTogether::SeedCatalog::GeographyCatalog.plant(:provinces)
  end

  def open_catalog
    capybara_login_as_platform_manager
    visit better_together.seed_catalog_seeds_path(locale: I18n.default_locale)
    expect(page).to have_css('#seed-catalog-billing_tax-table')
    page.execute_script('arguments[0].scrollIntoView({block: "center"})', find('#seed-catalog-billing_tax'))
  end

  def narrative(title:, step:, callouts:)
    { title:, audience: %w[platform_manager developer], journey_step: step,
      callouts: callouts.map { |callout| callout.slice(:id, :title, :description) },
      accessibility_notes: 'Plant buttons carry an aria-label naming the packet; a blocked or planted packet has a real ' \
                           'disabled attribute, and status is shown in text as well as colour.' }
  end

  it 'captures the tax packet held back until the geography provinces are planted' do
    callouts = [
      { id: 'blocked', selector: '#plant-billing_tax_canada-missing-prerequisites', title: 'Held back',
        description: 'Zones are tied to the seeded provinces, so the packet cannot be planted until Provinces & Territories are.',
        bullets: ['Names the geography category to plant first.'] },
      { id: 'plant_button', selector: '#plant-billing_tax_canada-btn', title: 'Plant this packet (disabled)',
        description: 'Disabled while the provinces are missing; the server refuses a hand-made POST too.',
        bullets: ['The button is disabled, not only styled.'] }
    ]
    BetterTogether::CapybaraScreenshotEngine.capture(
      'seed_catalog_billing_tax_blocked', device: :both, metadata: screenshot_metadata(flow: 'seed_catalog_billing_tax'),
                                          callouts: callouts.map { |callout| callout.except(:description) },
                                          narrative: narrative(title: 'Tax seed packet: waiting on geography', callouts:,
                                                               step: 'As a platform manager, I see the tax packet waits on the provinces it names.')
    ) do
      open_catalog
      expect(page).to have_css('#plant-billing_tax_canada-missing-prerequisites')
    end
  end

  def capture_ready(name, title, callout)
    plant_geography
    BetterTogether::CapybaraScreenshotEngine.capture(
      name, device: :both, metadata: screenshot_metadata(flow: 'seed_catalog_billing_tax'),
            callouts: [callout.except(:description)],
            narrative: narrative(title:, callouts: [callout], step: 'With the provinces planted, I can plant one tax packet or all of them.')
    ) do
      open_catalog
      expect(page).to have_css('.billing_tax_canada-status-badge', text: 'Not planted')
      expect(page).to have_no_css('#plant-billing_tax_canada-btn[disabled]')
    end
  end

  it 'captures the single tax packet ready to plant' do
    capture_ready('seed_catalog_billing_tax_ready_one', 'Tax seed packet: plant one packet',
                  { id: 'plant_button', selector: '#plant-billing_tax_canada-btn', title: 'Plant one packet',
                    description: 'Records the Canadian packet as a Seed, then adds the categories, a zone for each province and its rates.',
                    bullets: ['Zones are tied to the Geography::State rows.', 'Adds what is missing; never changes a rate.'] })
  end

  it 'captures Plant All for the tax packets' do
    capture_ready('seed_catalog_billing_tax_ready_all', 'Tax seed packet: Plant All',
                  { id: 'plant_all', selector: '#plant-all-billing_tax-btn', title: 'Plant All',
                    description: 'Plants every tax packet whose geography is in place. Idempotent.',
                    bullets: ['Skips a packet whose provinces are not planted.'] })
  end

  it 'captures the tax packet planted through the single packet button' do
    plant_geography
    BetterTogether::SeedCatalog::BillingTaxCatalog.plant(:billing_tax_canada)
    capture_planted('seed_catalog_billing_tax_planted_one', 'Tax seed packet: planted one packet')
  end

  it 'captures the tax packet planted through Plant All' do
    plant_geography
    BetterTogether::SeedCatalog::BillingTaxCatalog.plant_all
    capture_planted('seed_catalog_billing_tax_planted_all', 'Tax seed packet: planted with Plant All')
  end

  def capture_planted(name, title)
    callouts = [
      { id: 'planted_badge', selector: '.billing_tax_canada-status-badge', title: 'Planted',
        description: 'Green once every zone the packet names is on the platform: 13 zones with their rates.',
        bullets: ['Thirteen zones, one per province and territory.'] }
    ]
    BetterTogether::CapybaraScreenshotEngine.capture(
      name, device: :both, metadata: screenshot_metadata(flow: 'seed_catalog_billing_tax'),
            callouts: callouts.map { |callout| callout.except(:description) },
            narrative: narrative(title:, callouts:, step: 'After planting, the catalog shows the tax packet as planted.')
    ) do
      open_catalog
      expect(page).to have_css('.billing_tax_canada-status-badge', text: 'Planted')
      expect(host_platform.billing_tax_zones.count).to eq(13)
    end
  end
end
# rubocop:enable RSpec/NoExpectationExample
