# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for membership review remediation',
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  let(:locale) { I18n.default_locale }
  let(:password) { 'SecureTest123!@#' }
  let!(:host_platform) do
    configure_host_platform.tap do |platform|
      platform.update!(privacy: 'private', requires_invitation: true, allow_membership_requests: false)
      platform.primary_community.update!(allow_membership_requests: false)
    end
  end
  let!(:platform_manager_role) do
    BetterTogether::Role.find_by(identifier: 'platform_manager', resource_type: 'BetterTogether::Platform') ||
      create(:better_together_role, :platform_manager)
  end
  let!(:community_manager_role) do
    BetterTogether::Role.find_by(identifier: 'community_manager',
                                 resource_type: 'BetterTogether::Community') ||
      create(:better_together_role,
             identifier: 'community_manager',
             name: 'Community Manager',
             resource_type: 'BetterTogether::Community')
  end
  let!(:platform_manager) do
    create(:better_together_user, :confirmed,
           email: "membership-review-platform-manager-#{SecureRandom.hex(4)}@example.test",
           password:,
           person_attributes: { name: 'Platform Review Steward' })
  end
  let!(:community_manager) do
    create(:better_together_user, :confirmed,
           email: "membership-review-community-manager-#{SecureRandom.hex(4)}@example.test",
           password:,
           person_attributes: { name: 'Community Review Steward' })
  end
  let!(:review_community) do
    create(:better_together_community,
           name: 'Harbour Gardeners',
           privacy: 'public',
           allow_membership_requests: false)
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    BetterTogether::AccessControlBuilder.seed_data

    create(:better_together_person_platform_membership,
           joinable: host_platform,
           member: platform_manager.person,
           role: platform_manager_role)
    create(:better_together_person_community_membership,
           joinable: review_community,
           member: community_manager.person,
           role: community_manager_role)

    create(:better_together_joatu_membership_request,
           target: review_community,
           requestor_name: 'Alex Applicant',
           requestor_email: 'alex.applicant@example.test',
           created_at: 10.minutes.ago)
    create(:better_together_joatu_membership_request,
           target: review_community,
           requestor_name: 'Jordan Requestor',
           requestor_email: 'jordan.requestor@example.test',
           created_at: 6.minutes.ago)
    create(:better_together_joatu_membership_request,
           target: review_community,
           requestor_name: 'Sam Organizer',
           requestor_email: 'sam.organizer@example.test',
           created_at: 3.minutes.ago)
  end

  after do
    Current.platform = nil
  end

  it 'captures the host dashboard membership review queue' do
    result = BetterTogether::CapybaraScreenshotEngine.capture(
      'membership_review_host_dashboard_queue',
      device: :both,
      metadata: screenshot_metadata(role: 'platform_manager', flow: 'host_dashboard_review_queue'),
      callouts: [
        {
          selector: 'section[aria-labelledby="membership-review-heading"] .table-responsive',
          title: 'Host dashboard now exposes a review queue',
          bullets: [
            'Platform managers can reach membership review from the normal dashboard without typing a URL.',
            'Each row shows open-request counts, recent requester activity, and a direct review action.',
            'The queue works even when membership requests are currently closed, so stale review work stays discoverable.'
          ]
        }
      ]
    ) do
      login_as(platform_manager, scope: :user)
      visit better_together.host_dashboard_path(locale:)

      expect(page).to have_text('Membership review queue')
      expect(page).to have_text('Harbour Gardeners')
      expect(page).to have_link('Review queue',
                                href: better_together.community_membership_requests_path(review_community, locale:))
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/membership_review_host_dashboard_queue.png')
    expect(result[:mobile]).to end_with('docs/screenshots/mobile/membership_review_host_dashboard_queue.png')
  end

  it 'captures the community page membership review shortcut' do
    result = BetterTogether::CapybaraScreenshotEngine.capture(
      'membership_review_community_shortcut',
      device: :both,
      metadata: screenshot_metadata(role: 'community_manager', flow: 'community_page_review_shortcut'),
      callouts: [
        {
          selector: 'section[aria-labelledby="community-membership-review-heading"]',
          title: 'Community managers get a visible review shortcut',
          bullets: [
            'The community page itself now announces pending membership requests.',
            'The badge gives a quick count, while the button opens the full review queue.',
            'This keeps day-to-day community stewardship in one surface instead of splitting it across hidden routes.'
          ]
        }
      ]
    ) do
      login_as(community_manager, scope: :user)
      visit better_together.community_path(review_community, locale:)

      expect(page).to have_text('Membership request review')
      expect(page).to have_text('Harbour Gardeners has 3 open membership requests ready for review.')
      expect(page).to have_text('3 open requests')
      expect(page).to have_link('Review requests',
                                href: better_together.community_membership_requests_path(review_community, locale:))
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/membership_review_community_shortcut.png')
    expect(result[:mobile]).to end_with('docs/screenshots/mobile/membership_review_community_shortcut.png')
  end

  private

  def screenshot_metadata(role:, flow:)
    {
      locale:,
      role:,
      feature_set: 'membership_review_access_remediation',
      flow:,
      source_spec: self.class.metadata[:file_path]
    }
  end
end
