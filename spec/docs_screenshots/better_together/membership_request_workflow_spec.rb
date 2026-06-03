# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for membership request workflow',
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  let!(:platform) do
    configure_host_platform.tap do |record|
      record.update!(privacy: 'private', requires_invitation: true, allow_membership_requests: true)
      record.primary_community.update!(allow_membership_requests: true)
    end
  end
  let!(:community) { platform.primary_community }
  let!(:community_manager_role) do
    BetterTogether::Role.find_by(identifier: 'community_manager',
                                 resource_type: 'BetterTogether::Community') ||
      create(:better_together_role,
             identifier: 'community_manager',
             name: 'Community Manager',
             resource_type: 'BetterTogether::Community')
  end
  let!(:manager) do
    create(:better_together_user, :confirmed, password: 'SecureTest123!@#').tap do |user|
      create(:better_together_person_community_membership,
             joinable: community,
             member: user.person,
             role: community_manager_role)
    end
  end
  let!(:open_request) do
    create(:better_together_joatu_membership_request,
           target: community,
           requestor_name: 'Alex Applicant',
           requestor_email: 'alex.applicant@example.test',
           referral_source: 'Community event',
           status: 'open')
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'
  end

  it 'captures the private registration interstitial with membership request form' do
    capture_docs_screenshot('membership_request_registration_interstitial') do
      visit '/en/users/sign-up'

      expect(page).to have_text('Invitation')
      expect(page).to have_text('Request membership instead')
      expect(page).to have_text(community.name)
    end
  end

  it 'captures the membership request review queue' do
    capture_docs_screenshot('membership_request_review_queue') do
      sign_in_for_docs_capture
      visit better_together.community_membership_requests_path(community, locale: I18n.default_locale)

      expect(page).to have_text('Membership Requests')
      expect(page).to have_text('Alex Applicant')
      expect(page).to have_text('Approve')
    end
  end

  it 'captures the membership request review detail view' do
    capture_docs_screenshot('membership_request_review_detail') do
      sign_in_for_docs_capture
      visit better_together.community_membership_request_path(community, open_request, locale: I18n.default_locale)

      expect(page).to have_text('Membership Request')
      expect(page).to have_text('Alex Applicant')
      expect(page).to have_text('Approve')
      expect(page).to have_text('Decline')
    end
  end

  private

  def capture_docs_screenshot(name, &)
    BetterTogether::CapybaraScreenshotEngine.capture(
      name,
      device: :both,
      metadata: {
        locale: I18n.default_locale,
        role: 'community_manager',
        feature_set: 'membership_request_workflow',
        source_spec: self.class.metadata[:file_path]
      },
      &
    )
  end

  def sign_in_for_docs_capture
    login_as(manager, scope: :user)
  end
end
