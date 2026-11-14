# frozen_string_literal: true

# Capture command (run from repo root):
#   RUN_DOCS_SCREENSHOTS=1 bin/dc-run bundle exec prspec \
#     spec/docs_screenshots/better_together/account_deletion_spec.rb
#
# Assets land in docs/screenshots/{desktop,mobile}/account_deletion_*.{png,json,narrative.yml}

require 'rails_helper'

RSpec.describe 'Documentation screenshots for account deletion',
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let(:password) { 'SecureTest123!@#' }
  let(:host_platform) do
    configure_host_platform.tap { |platform| platform.update!(privacy: 'public', requires_invitation: false) }
  end
  let(:steward_role) { BetterTogether::Role.find_by!(identifier: 'platform_steward') }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
  end

  after { Current.platform = nil }

  def sole_steward
    BetterTogether::PersonPlatformMembership.where(joinable: host_platform, role: steward_role).destroy_all
    user = find_or_create_test_user('steward-docs@example.test', password, :user)
    BetterTogether::PersonPlatformMembership.create!(member: user.person, joinable: host_platform,
                                                     role: steward_role, status: 'active')
    user
  end

  def metadata_for(flow, role)
    { locale: I18n.default_locale, role:, feature_set: 'account_deletion', flow:,
      source_spec: self.class.metadata[:file_path] }
  end

  def expect_capture(slug, flow, role, narrative, callouts, &)
    result = BetterTogether::CapybaraScreenshotEngine.capture(
      slug, device: :both, metadata: metadata_for(flow, role), narrative:, callouts:, &
    )
    expect(result[:desktop]).to end_with("docs/screenshots/desktop/#{slug}.png")
    expect(result[:mobile]).to end_with("docs/screenshots/mobile/#{slug}.png")
  end

  def scroll_to(selector)
    expect(page).to have_css(selector)
    page.execute_script("document.querySelector('#{selector}').scrollIntoView({block: 'center'})")
  end

  it 'captures the normal member deletion request form' do
    user = find_or_create_test_user('member-docs@example.test', password, :user)
    callouts = [{ id: 'form', selector: '#person-deletion-request-form', title: 'Request deletion',
                  bullets: ['Optionally say why, then send the request.', 'It is reviewed before anything is removed.'] }]
    narrative = { title: 'Request account deletion', audience: %w[end_user],
                  journey_step: 'As a member, I can ask for my account on this platform to be deleted.',
                  callouts: [{ id: 'form', title: 'Request deletion', description: 'Starts the review.' }],
                  accessibility_notes: 'The reason field has a visible label.' }

    expect_capture('account_deletion_member', 'member', 'user', narrative, callouts) do
      capybara_sign_in_user(user.email, password)
      visit edit_user_registration_path(locale: I18n.default_locale)
      scroll_to('#person-deletion-request-form')
    end
  end

  it 'captures the last steward pointer to the platform removal form' do
    steward = sole_steward
    callouts = [{ id: 'notice', selector: '#last-steward-deletion-notice', title: 'Last steward',
                  bullets: ['Account deletion is replaced by a platform removal request.',
                            'This keeps the platform from being left without a steward.'] }]
    narrative = { title: 'Last steward account deletion', audience: %w[platform_steward],
                  journey_step: 'As the only steward, I am pointed to the platform removal request.',
                  callouts: [{ id: 'notice', title: 'Last steward', description: 'Explains why and links on.' }],
                  accessibility_notes: 'The notice has role note and a descriptive link.' }

    expect_capture('account_deletion_last_steward', 'last_steward', 'platform_steward', narrative, callouts) do
      capybara_sign_in_user(steward.email, password)
      visit edit_user_registration_path(locale: I18n.default_locale)
      scroll_to('#last-steward-deletion-notice')
    end
  end

  it 'captures the platform removal request form and its pending state' do
    steward = sole_steward
    callouts = [{ id: 'form', selector: '#platform-deletion-request-form', title: 'Platform removal request',
                  bullets: ['Sent to the host platform stewards.', 'Can be cancelled while pending.'] }]
    narrative = { title: 'Request platform removal', audience: %w[platform_steward],
                  journey_step: 'As the only steward, I can ask host stewards to remove the platform.',
                  callouts: [{ id: 'form', title: 'Platform removal request', description: 'Goes to host stewards.' }],
                  accessibility_notes: 'The reason field is labelled and has a hint linked by aria-describedby.' }

    expect_capture('account_deletion_platform_request', 'platform_request', 'platform_steward', narrative, callouts) do
      capybara_sign_in_user(steward.email, password)
      visit new_platform_deletion_request_path(locale: I18n.default_locale)
      scroll_to('#platform-deletion-request-form')
    end

    BetterTogether::PlatformDeletionRequest.create!(platform: host_platform, requested_by: steward.person,
                                                    requested_at: Time.current)
    pending_callouts = [{ id: 'pending', selector: '#platform-deletion-request-page .alert-info', title: 'Pending',
                          bullets: ['Shows when the request was sent.', 'Cancel returns to the form.'] }]
    expect_capture('account_deletion_platform_request_pending', 'platform_request_pending', 'platform_steward',
                   narrative.merge(title: 'Platform removal request pending'), pending_callouts) do
      capybara_sign_in_user(steward.email, password)
      visit new_platform_deletion_request_path(locale: I18n.default_locale)
      scroll_to('#platform-deletion-request-page .alert-info')
    end
  end
end
