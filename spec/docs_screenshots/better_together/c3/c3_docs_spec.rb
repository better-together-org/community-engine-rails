# frozen_string_literal: true

require 'rails_helper'

# C3 Tree Seeds documentation screenshots.
#
# Captures desktop and mobile screenshots of:
#   - C3 balance card on user profile
#   - Settlement status on agreement show view
#   - Tree Seeds exchange settings on platform connection admin form
#   - C3 contribution history
#
# Run with:
#   RUN_DOCS_SCREENSHOTS=1 bundle exec rspec spec/docs_screenshots/better_together/c3/ --format documentation
#
# Output: docs/screenshots/desktop/ and docs/screenshots/mobile/
# Each screenshot is paired with a JSON sidecar (metadata, URL, viewport, timestamp).
RSpec.describe 'Documentation screenshots for C3 Tree Seeds', # rubocop:todo Metrics/BlockLength
               :as_admin, :docs_screenshot, :js, retry: 0, type: :feature do
  let!(:admin_user) { find_or_create_test_user('admin@example.test', 'SecureAdmin123!@#', :administrator) }
  let!(:earner_user) { find_or_create_test_user('earner@example.test', 'SecureTest123!@#', :user) }
  let!(:provider_user) { find_or_create_test_user('provider@example.test', 'SecureTest123!@#', :user) }

  let!(:earner_balance) do
    create(
      :c3_balance,
      holder: earner_user.person,
      available_millitokens: 12_500,  # 12.5 Tree Seeds
      locked_millitokens: 3_000,       # 3.0 Tree Seeds (reserved)
      lifetime_earned_millitokens: 55_000 # 55.0 Tree Seeds earned total
    )
  end

  let!(:provider_balance) do
    create(
      :c3_balance,
      holder: provider_user.person,
      available_millitokens: 8_000,
      locked_millitokens: 0,
      lifetime_earned_millitokens: 20_000
    )
  end

  let!(:c3_offer) do
    create(
      :joatu_offer,
      creator: provider_user.person,
      title: 'Help setting up your home network',
      description: 'I can help you set up a secure home network. One session, 1-2 hours.',
      c3_price_millitokens: 3_000
    )
  end

  let!(:agreement) do
    create(
      :joatu_agreement,
      offer: c3_offer,
      c3_price_millitokens: 3_000
    )
  end

  let!(:settlement) do
    create(
      :joatu_settlement,
      agreement: agreement,
      payer: earner_user.person,
      recipient: provider_user.person,
      c3_millitokens: 3_000,
      status: 'pending'
    )
  end

  let!(:c3_tokens) do
    [
      create(:c3_token, earner: earner_user.person, contribution_type: :compute_cpu,
                        c3_millitokens: 10_000, source_system: 'borgberry',
                        status: 'confirmed', confirmed_at: 3.days.ago),
      create(:c3_token, earner: earner_user.person, contribution_type: :volunteer,
                        c3_millitokens: 25_000, source_system: 'borgberry',
                        status: 'confirmed', confirmed_at: 1.day.ago),
      create(:c3_token, earner: earner_user.person, contribution_type: :code_review,
                        c3_millitokens: 20_000, source_system: 'borgberry',
                        status: 'confirmed', confirmed_at: 12.hours.ago)
    ]
  end

  let!(:peer_platform) do
    create(:platform, name: 'Newcomer Navigator NL', identifier: 'newcomernavigatornl')
  end

  let!(:platform_connection) do
    create(
      :platform_connection,
      source_platform: BetterTogether::Platform.host,
      target_platform: peer_platform,
      status: 'active',
      allow_c3_exchange: false,
      c3_exchange_rate: 1.0
    )
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate C3 documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'
  end

  it 'captures the C3 balance card on a user profile page' do
    capture_c3_screenshot('c3_balance_card_user_profile') do
      sign_in_as_for_docs(earner_user)
      visit better_together.person_path(earner_user.person, locale: I18n.default_locale)
      expect(page).to have_css('[aria-label*="Tree Seeds"]')
      expect(page).to have_text('Available')
      expect(page).to have_text('12.5')
    end
  end

  it 'captures the C3 balance card cross-platform toggle' do
    create(
      :c3_balance,
      holder: earner_user.person,
      origin_platform: peer_platform,
      available_millitokens: 5_000,
      locked_millitokens: 0,
      lifetime_earned_millitokens: 5_000
    )

    capture_c3_screenshot('c3_balance_card_cross_platform') do
      sign_in_as_for_docs(earner_user)
      visit better_together.person_path(earner_user.person, locale: I18n.default_locale)
      # Expand cross-platform section if it exists
      find('[data-action*="cross-platform"], [aria-controls*="cross-platform"]',
           wait: 5, raise: false)&.click
      expect(page).to have_text('Tree Seeds')
    end
  end

  it 'captures settlement status on an agreement show view — pending' do
    capture_c3_screenshot('c3_settlement_status_pending') do
      sign_in_as_for_docs(earner_user)
      visit better_together.joatu_agreement_path(agreement, locale: I18n.default_locale)
      expect(page).to have_text('Tree Seeds')
      expect(page).to have_text('reserved')
    end
  end

  it 'captures settlement status on an agreement show view — completed' do
    settlement.update!(status: 'completed',
                       completed_at: 30.minutes.ago,
                       c3_token: c3_tokens.first)

    capture_c3_screenshot('c3_settlement_status_completed') do
      sign_in_as_for_docs(earner_user)
      visit better_together.joatu_agreement_path(agreement, locale: I18n.default_locale)
      expect(page).to have_text('Tree Seeds')
      expect(page).to have_text(/exchanged/i)
    end
  end

  it 'captures the C3 exchange settings on the admin platform connection form' do
    capture_c3_screenshot('c3_admin_platform_connection_exchange_settings') do
      sign_in_as_for_docs(admin_user)
      visit better_together.edit_admin_platform_connection_path(
        platform_connection, locale: I18n.default_locale
      )
      expect(page).to have_text('Tree Seeds')
      expect(page).to have_text('Allow')
    end
  end

  it 'captures the insufficient balance flash on agreement accept' do
    # Set earner balance to less than the offer price
    earner_balance.update!(available_millitokens: 500, locked_millitokens: 0)

    capture_c3_screenshot('c3_insufficient_balance_flash') do
      sign_in_as_for_docs(earner_user)
      visit better_together.joatu_agreement_path(agreement, locale: I18n.default_locale)
      click_on 'Accept', match: :first, raise: false
      expect(page).to have_css('.alert, .flash', wait: 5)
    end
  end

  private

  def capture_c3_screenshot(name, &)
    BetterTogether::CapybaraScreenshotEngine.capture(
      name,
      device: :both,
      metadata: {
        locale: I18n.default_locale,
        feature_set: 'c3_tree_seeds',
        source_spec: self.class.metadata[:file_path]
      },
      &
    )
  end

  def sign_in_as_for_docs(user)
    capybara_login_as_user(user)
  end
end
