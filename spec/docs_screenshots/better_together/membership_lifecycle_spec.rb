# frozen_string_literal: true

# Capture command (run from repo root):
#   RUN_DOCS_SCREENSHOTS=1 bin/dc-run bundle exec prspec \
#     spec/docs_screenshots/better_together/membership_lifecycle_spec.rb
#
# Assets land in docs/screenshots/{desktop,mobile}/membership_lifecycle_*.{png,json,narrative.yml}

require 'rails_helper'

RSpec.describe 'Documentation screenshots for membership lifecycle',
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
  let(:role) { BetterTogether::Role.find_by!(identifier: 'platform_analytics_viewer') }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
  end

  after { Current.platform = nil }

  def metadata_for(flow, role_name)
    { locale: I18n.default_locale, role: role_name, feature_set: 'membership_lifecycle', flow:,
      source_spec: self.class.metadata[:file_path] }
  end

  def scroll_to(selector)
    expect(page).to have_css(selector)
    page.execute_script("document.querySelector('#{selector}').scrollIntoView({block: 'center'})")
  end

  def member_in(state)
    person = create(:better_together_person, platform_id: host_platform.id, name: "Docs #{state} member")
    membership = BetterTogether::PersonPlatformMembership.create!(member: person, joinable: host_platform, role:,
                                                                  status: 'active', source: 'invitation')
    membership.suspend!(reason: 'On leave', actor: nil) if state == 'suspended'
    membership
  end

  it 'captures a current member with its lifecycle controls' do
    manager = find_or_create_test_user('manager-docs@example.test', password, :platform_manager)
    membership = member_in('current')
    id = ActionView::RecordIdentifier.dom_id(membership, :lifecycle)
    callouts = [{ id: 'lifecycle', selector: "##{id}", title: 'Status and actions',
                  bullets: ['Shows the status, where the membership came from and since when.',
                            'Suspend or end keeps the row as history.'] }]
    narrative = { title: 'Membership status and actions', audience: %w[platform_steward],
                  journey_step: 'As a steward, I can see a member status and suspend or end the membership.',
                  callouts: [{ id: 'lifecycle', title: 'Status and actions', description: 'Lifecycle controls.' }],
                  accessibility_notes: 'Buttons have visible text labels.' }

    result = BetterTogether::CapybaraScreenshotEngine.capture(
      'membership_lifecycle_current', device: :both, metadata: metadata_for('current', 'platform_steward'),
                                      narrative:, callouts:
    ) do
      capybara_sign_in_user(manager.email, password)
      visit platform_person_platform_memberships_path(host_platform, locale: I18n.default_locale)
      scroll_to("##{id}")
    end
    expect(result[:desktop]).to end_with('docs/screenshots/desktop/membership_lifecycle_current.png')
  end

  it 'captures a suspended member with the reinstate control' do
    manager = find_or_create_test_user('manager-docs@example.test', password, :platform_manager)
    membership = member_in('suspended')
    id = ActionView::RecordIdentifier.dom_id(membership, :lifecycle)
    callouts = [{ id: 'lifecycle', selector: "##{id}", title: 'Suspended',
                  bullets: ['A suspended member keeps the row but loses access.', 'Reinstate restores it.'] }]
    narrative = { title: 'Suspended membership', audience: %w[platform_steward],
                  journey_step: 'As a steward, I can reinstate a suspended member.',
                  callouts: [{ id: 'lifecycle', title: 'Suspended', description: 'Reinstate control.' }],
                  accessibility_notes: 'Status is text, not color alone.' }

    result = BetterTogether::CapybaraScreenshotEngine.capture(
      'membership_lifecycle_suspended', device: :both, metadata: metadata_for('suspended', 'platform_steward'),
                                        narrative:, callouts:
    ) do
      capybara_sign_in_user(manager.email, password)
      visit platform_person_platform_memberships_path(host_platform, locale: I18n.default_locale)
      scroll_to("##{id}")
    end
    expect(result[:mobile]).to end_with('docs/screenshots/mobile/membership_lifecycle_suspended.png')
  end
end
