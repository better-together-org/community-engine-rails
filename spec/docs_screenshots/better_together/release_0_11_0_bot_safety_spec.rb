# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for 0.11.0 bot safety',
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  let!(:community_manager_role) do
    BetterTogether::Role.find_by(identifier: 'community_manager',
                                 resource_type: 'BetterTogether::Community') ||
      create(:better_together_role,
             identifier: 'community_manager',
             name: 'Community Manager',
             resource_type: 'BetterTogether::Community')
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'
  end

  it 'captures the public sign-up form' do
    configure_host_platform.tap do |platform|
      platform.update!(privacy: 'public', requires_invitation: false, allow_membership_requests: true)
      platform.primary_community.update!(allow_membership_requests: true)
    end

    capture_docs_screenshot('release_0_11_0_bot_safety_signup_form', role: 'guest', flow: 'signup') do
      visit better_together.new_user_registration_path(locale: I18n.default_locale)

      expect(page).to have_text(I18n.t('devise.registrations.new.sign_up'))
      expect(page).to have_css('form')
    end
  end

  it 'captures the invitation-required membership request interstitial' do
    platform = configure_host_platform.tap do |record|
      record.update!(privacy: 'private', requires_invitation: true, allow_membership_requests: true)
      record.primary_community.update!(allow_membership_requests: true)
    end

    capture_docs_screenshot('release_0_11_0_bot_safety_membership_request_interstitial',
                            role: 'guest',
                            flow: 'membership_request_interstitial') do
      visit better_together.new_user_registration_path(locale: I18n.default_locale)

      expect(page).to have_text('Request membership instead')
      expect(page).to have_text(platform.primary_community.name)
    end
  end

  it 'captures the membership request review queue' do
    platform = configure_host_platform.tap do |record|
      record.update!(privacy: 'private', requires_invitation: true, allow_membership_requests: true)
      record.primary_community.update!(allow_membership_requests: true)
    end
    community = platform.primary_community
    manager = create(:better_together_user, :confirmed, password: 'SecureTest123!@#')
    create(:better_together_person_community_membership,
           joinable: community,
           member: manager.person,
           role: community_manager_role)
    create(:better_together_joatu_membership_request,
           target: community,
           requestor_name: 'Alex Applicant',
           requestor_email: 'alex.applicant@example.test',
           referral_source: 'Community event',
           status: 'open')

    capture_docs_screenshot('release_0_11_0_bot_safety_membership_review_queue',
                            role: 'community_manager',
                            flow: 'membership_review_queue') do
      login_as(manager, scope: :user)
      visit better_together.community_membership_requests_path(community, locale: I18n.default_locale)

      expect(page).to have_text('Membership Requests')
      expect(page).to have_text('Alex Applicant')
    end
  end

  it 'captures the safety report form' do
    configure_host_platform.tap do |platform|
      platform.update!(privacy: 'public', requires_invitation: false, allow_membership_requests: true)
    end
    reporter = create(:better_together_user, :confirmed)
    target_person = create(:better_together_person, name: 'Documentation Target')

    capture_docs_screenshot('release_0_11_0_bot_safety_report_form', role: 'user', flow: 'safety_report') do
      login_as(reporter, scope: :user)
      visit better_together.new_report_path(
        locale: I18n.default_locale,
        reportable_type: 'BetterTogether::Person',
        reportable_id: target_person.id
      )

      expect(page).to have_css('form', wait: 10)
      expect(page).to have_text('Report a safety concern')
    end
  end

  private

  def capture_docs_screenshot(name, role:, flow:, &)
    BetterTogether::CapybaraScreenshotEngine.capture(
      name,
      device: :both,
      metadata: {
        locale: I18n.default_locale,
        role:,
        flow:,
        source_spec: self.class.metadata[:file_path]
      },
      &
    )
  end
end
