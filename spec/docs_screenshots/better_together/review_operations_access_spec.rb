# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for safety and federation review access',
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  let(:locale) { I18n.default_locale }
  let(:host_platform) { configure_host_platform }
  let(:password) { 'SecureTest123!@#' }
  let(:platform_manager) do
    find_or_create_test_user('review-operations-manager@example.test', password, :platform_manager)
  end
  let(:safety_reviewer) do
    create(:better_together_user, :confirmed,
           email: "review-operations-safety-#{SecureRandom.hex(4)}@example.test",
           password:)
  end
  let!(:reported_person) { create(:better_together_person, name: 'Safety Review Reported Person') }
  let!(:report_record) do
    create(:report,
           reporter: create(:better_together_person, name: 'Safety Review Reporter'),
           reportable: reported_person,
           category: 'boundary_violation',
           harm_level: 'urgent',
           retaliation_risk: true,
           requested_outcome: 'boundary_support',
           reason: 'Repeated unwanted contact in shared spaces')
  end
  let!(:safety_case) do
    BetterTogether::Safety::Case.create!(
      report: report_record,
      category: report_record.category,
      harm_level: report_record.harm_level,
      requested_outcome: report_record.requested_outcome,
      retaliation_risk: report_record.retaliation_risk,
      consent_to_contact: report_record.consent_to_contact,
      consent_to_restorative_process: report_record.consent_to_restorative_process
    )
  end
  let!(:federation_target_one) do
    create(:better_together_platform,
           name: 'Neighbourhood Commons',
           identifier: "neighbourhood-commons-#{SecureRandom.hex(4)}")
  end
  let!(:federation_target_two) do
    create(:better_together_platform,
           name: 'Coastal Mutual Aid',
           identifier: "coastal-mutual-aid-#{SecureRandom.hex(4)}")
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    BetterTogether::AccessControlBuilder.seed_data

    grant_platform_permission(safety_reviewer, 'manage_platform_safety')
    grant_platform_permission(platform_manager, 'manage_network_connections')

    BetterTogether::Safety::Note.create!(
      safety_case:,
      author: safety_reviewer.person,
      visibility: 'participant_visible',
      body: 'Participant follow-up note is ready for review.'
    )

    create(:better_together_platform_connection,
           source_platform: host_platform,
           target_platform: federation_target_one,
           status: 'pending',
           connection_kind: 'peer',
           updated_at: 6.minutes.ago)
    create(:better_together_platform_connection,
           :active,
           source_platform: host_platform,
           target_platform: federation_target_two,
           connection_kind: 'member',
           updated_at: 2.minutes.ago)
  end

  after do
    Current.platform = nil
  end

  it 'captures the host platform safety review panel' do
    result = BetterTogether::CapybaraScreenshotEngine.capture(
      'safety_review_host_platform_panel',
      device: :both,
      metadata: screenshot_metadata(role: 'safety_reviewer', flow: 'host_platform_profile'),
      callouts: [
        {
          selector: '#safety',
          title: 'Safety reviewers now have a visible operational workspace',
          bullets: [
            'The host platform profile exposes the Safety tab with queue-level counts and direct actions.',
            'Reviewers can jump straight to the safety-case queue or submitted reports from the same surface.',
            'Urgent, retaliation-risk, and participant-update counts stay visible without exposing reporter detail broadly.'
          ]
        }
      ]
    ) do
      login_as(safety_reviewer, scope: :user)
      visit better_together.platform_path(host_platform, locale:)
      click_link 'Safety'

      expect(page).to have_text('Safety Review')
      expect(page).to have_link('Open Review Queue', href: better_together.safety_cases_path(locale:))
      expect(page).to have_link('Review Submitted Reports', href: better_together.reports_path(locale:))
      expect(page).to have_text('Retaliation Risk')
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/safety_review_host_platform_panel.png')
    expect(result[:mobile]).to end_with('docs/screenshots/mobile/safety_review_host_platform_panel.png')
  end

  it 'captures the host dashboard federation review queue' do
    result = BetterTogether::CapybaraScreenshotEngine.capture(
      'federation_review_host_dashboard_queue',
      device: :both,
      metadata: screenshot_metadata(role: 'platform_manager', flow: 'host_dashboard_federation_queue'),
      callouts: [
        {
          selector: '#platform-connection-review-heading',
          avoid_container_selector: 'section[aria-labelledby="platform-connection-review-heading"]',
          title: 'The host dashboard now exposes federation review work',
          bullets: [
            'Operators who already manage network connections can find pending and active links from the normal dashboard.',
            'Each row shows the connected platform, direction, current state, and a direct link into the connection record.',
            'This complements steward notifications by keeping the queue discoverable without typing a direct URL.'
          ]
        }
      ]
    ) do
      login_as(platform_manager, scope: :user)
      visit better_together.host_dashboard_path(locale:)
      page.execute_script <<~JS
        document
          .querySelector('section[aria-labelledby="platform-connection-review-heading"]')
          ?.scrollIntoView({ block: 'center' });
      JS

      expect(page).to have_text('Federation review queue')
      expect(page).to have_text('Neighbourhood Commons')
      expect(page).to have_link('Review connections', href: better_together.platform_connections_path(locale:))
      expect(page).to have_text('Pending')
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/federation_review_host_dashboard_queue.png')
    expect(result[:mobile]).to end_with('docs/screenshots/mobile/federation_review_host_dashboard_queue.png')
  end

  private

  def grant_platform_permission(user, permission_identifier)
    role = create(:better_together_role, :platform_role)
    permission = BetterTogether::ResourcePermission.find_by!(identifier: permission_identifier)
    role.assign_resource_permissions([permission.identifier])
    host_platform.person_platform_memberships.find_or_create_by!(member: user.person, role:)
  end

  def screenshot_metadata(role:, flow:)
    {
      locale:,
      role:,
      feature_set: 'safety_and_federation_review_operations',
      flow:,
      source_spec: self.class.metadata[:file_path]
    }
  end
end
