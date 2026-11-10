# frozen_string_literal: true

# Capture command (run from repo root):
#   RUN_DOCS_SCREENSHOTS=1 bin/dc-run bundle exec prspec \
#     spec/docs_screenshots/better_together/seed_catalog_billing_agreements_spec.rb
#
# Assets land in docs/screenshots/{desktop,mobile}/seed_catalog_billing_agreements_*.{png,json,narrative.yml}
#
# See skills/ce-pr-docs/SKILL.md for the full PR documentation workflow.

require 'rails_helper'

# The expectations run inside the capture block.
# rubocop:disable RSpec/NoExpectationExample
RSpec.describe 'Documentation screenshots for the billing agreements seed catalog',
               :docs_screenshot,
               :js,
               :no_auth,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  include_context 'with builtin billing processors'

  let(:host_platform) do
    configure_host_platform.tap do |platform|
      platform.update!(privacy: 'public', requires_invitation: false, allow_membership_requests: false)
    end
  end
  let(:identifiers) { %w[subscription_agreement one_time_purchase_agreement offline_payment_terms] }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    # :no_auth and the explicit login in each example: see seed_catalog_spec.rb for why.
    Current.platform = host_platform
    host_platform.billing_agreement_requirements.destroy_all
    BetterTogether::Agreement.where(platform: host_platform, identifier: identifiers).destroy_all
  end

  after { Current.platform = nil }

  def screenshot_metadata
    { locale: I18n.default_locale, role: 'platform_manager', feature_set: 'seed_catalog_billing_agreements',
      flow: 'seed_catalog_billing_agreements', source_spec: self.class.metadata[:file_path] }
  end

  def open_catalog
    capybara_login_as_platform_manager
    visit better_together.seed_catalog_seeds_path(locale: I18n.default_locale)
    expect(page).to have_css('#seed-catalog-billing_agreements-table')
    page.execute_script('arguments[0].scrollIntoView({block: "center"})', find('#seed-catalog-billing_agreements'))
  end

  def narrative(title:, step:, callouts:)
    { title:, audience: %w[platform_manager developer], journey_step: step,
      callouts: callouts.map { |callout| callout.slice(:id, :title, :description) },
      accessibility_notes: 'The plant button carries an aria-label naming the packet; status is shown in text as well as colour.' }
  end

  it 'captures the purchase agreements ready to plant' do
    callouts = [{ id: 'plant_button', selector: '#plant-billing_purchase_agreements-btn', title: 'Plant the purchase agreements',
                  description: 'Adds the subscription, one-time purchase and offline payment agreements as drafts with placeholder text.',
                  bullets: ['Nothing needs planting first.', 'Nothing can be sold until a steward activates them.'] }]
    BetterTogether::CapybaraScreenshotEngine.capture(
      'seed_catalog_billing_agreements_ready', device: :both, metadata: screenshot_metadata,
                                               callouts: callouts.map { |callout| callout.except(:description) },
                                               narrative: narrative(title: 'Billing agreements: ready to plant', callouts:,
                                                                    step: 'I can plant the draft purchase agreements.')
    ) do
      open_catalog
      expect(page).to have_css('.billing_purchase_agreements-status-badge', text: 'Not planted')
      expect(page).to have_no_css('#plant-billing_purchase_agreements-btn[disabled]')
    end
  end

  it 'captures the purchase agreements planted' do
    BetterTogether::SeedCatalog::BillingAgreementsCatalog.plant(:billing_purchase_agreements)
    callouts = [{ id: 'planted_badge', selector: '.billing_purchase_agreements-status-badge', title: 'Planted',
                  description: 'Green once the three agreements and the purchases they cover are on the platform.',
                  bullets: ['They stay drafts until a steward activates them.'] }]
    BetterTogether::CapybaraScreenshotEngine.capture(
      'seed_catalog_billing_agreements_planted', device: :both, metadata: screenshot_metadata,
                                                 callouts: callouts.map { |callout| callout.except(:description) },
                                                 narrative: narrative(title: 'Billing agreements: planted', callouts:,
                                                                      step: 'After planting, the catalog shows the agreements as planted.')
    ) do
      open_catalog
      expect(page).to have_css('.billing_purchase_agreements-status-badge', text: 'Planted')
    end
  end
end
# rubocop:enable RSpec/NoExpectationExample
