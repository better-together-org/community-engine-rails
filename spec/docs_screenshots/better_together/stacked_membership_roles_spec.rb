# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for stacked membership roles',
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
      platform.primary_community&.update!(allow_membership_requests: false)
    end
  end
  let!(:platform_steward_role) do
    BetterTogether::Role.find_by(identifier: 'platform_steward', resource_type: 'BetterTogether::Platform') ||
      BetterTogether::Role.find_by(identifier: 'platform_manager', resource_type: 'BetterTogether::Platform') ||
      create(:better_together_role, :platform_manager)
  end
  let!(:network_admin_role) do
    BetterTogether::Role.find_by(identifier: 'network_admin', resource_type: 'BetterTogether::Platform') ||
      create(:better_together_role, identifier: 'network_admin', name: 'Network Admin',
                                    resource_type: 'BetterTogether::Platform')
  end
  let!(:community_organizer_role) do
    BetterTogether::Role.find_by(identifier: 'community_organizer', resource_type: 'BetterTogether::Community') ||
      create(:better_together_role, identifier: 'community_organizer', name: 'Community Organizer',
                                    resource_type: 'BetterTogether::Community')
  end
  let!(:community_coordinator_role) do
    BetterTogether::Role.find_by(identifier: 'community_coordinator', resource_type: 'BetterTogether::Community') ||
      create(:better_together_role, identifier: 'community_coordinator', name: 'Community Coordinator',
                                    resource_type: 'BetterTogether::Community')
  end
  let!(:platform_viewer) do
    create(:better_together_user, :confirmed,
           email: "stacked-platform-viewer-#{SecureRandom.hex(4)}@example.test",
           password:,
           person_attributes: { name: 'Platform Operations Lead' })
  end
  let!(:community_viewer) do
    create(:better_together_user, :confirmed,
           email: "stacked-community-viewer-#{SecureRandom.hex(4)}@example.test",
           password:,
           person_attributes: { name: 'Community Operations Lead' })
  end
  let!(:dual_role_person) { create(:better_together_person, name: 'Robin Steward') }
  let!(:review_community) do
    create(:better_together_community,
           name: 'Harbour Gardeners',
           privacy: 'private',
           allow_membership_requests: false)
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    BetterTogether::AccessControlBuilder.seed_data

    create(:better_together_person_platform_membership,
           joinable: host_platform,
           member: platform_viewer.person,
           role: platform_steward_role,
           status: 'active')
    create(:better_together_person_community_membership,
           joinable: review_community,
           member: community_viewer.person,
           role: community_organizer_role,
           status: 'active')

    create(:better_together_person_platform_membership,
           joinable: host_platform,
           member: dual_role_person,
           role: platform_steward_role,
           status: 'active')
    create(:better_together_person_platform_membership,
           joinable: host_platform,
           member: dual_role_person,
           role: network_admin_role,
           status: 'active')

    create(:better_together_person_community_membership,
           joinable: review_community,
           member: dual_role_person,
           role: community_organizer_role,
           status: 'active')
    create(:better_together_person_community_membership,
           joinable: review_community,
           member: dual_role_person,
           role: community_coordinator_role,
           status: 'active')
  end

  after do
    Current.platform = nil
  end

  it 'captures a platform members tab with stacked active roles' do
    result = BetterTogether::CapybaraScreenshotEngine.capture(
      'platform_membership_multi_role_cards',
      device: :both,
      metadata: screenshot_metadata(role: 'platform_steward', flow: 'platform_members_tab_stacked_roles'),
      callouts: [
        {
          selector: '#platform_members_list',
          title: 'The same person can now hold more than one active platform role',
          bullets: [
            'Each card represents one membership row, so a person can be both a platform steward and a network admin.',
            'Permissions come from the union of active rows instead of forcing one role to replace another.',
            'Removing one card removes only that role assignment, not the person’s other stewardship authority.'
          ]
        }
      ]
    ) do
      login_as(platform_viewer, scope: :user)
      visit better_together.platform_path(host_platform, locale:)

      click_link I18n.t('globals.tabs.members')
      expect(page).to have_css('#members.show')
      expect(page).to have_text('Robin Steward', count: 2)
      expect(page).to have_text(platform_steward_role.name)
      expect(page).to have_text(network_admin_role.name)
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/platform_membership_multi_role_cards.png')
    expect(result[:mobile]).to end_with('docs/screenshots/mobile/platform_membership_multi_role_cards.png')
  end

  it 'captures a community members tab with stacked active roles' do
    result = BetterTogether::CapybaraScreenshotEngine.capture(
      'community_membership_multi_role_cards',
      device: :both,
      metadata: screenshot_metadata(role: 'community_organizer', flow: 'community_members_tab_stacked_roles'),
      callouts: [
        {
          selector: '#members_list',
          title: 'Community stewardship can also be split across active role rows',
          bullets: [
            'The same person can carry more than one community responsibility at once when the roles are both active.',
            'Pending rows no longer widen access, so only active assignments contribute to what someone can manage or see.',
            'This makes time-bounded or partial revocation safer because one role can end without collapsing the rest.'
          ]
        }
      ]
    ) do
      login_as(community_viewer, scope: :user)
      visit better_together.community_path(review_community, locale:)

      click_link I18n.t('globals.tabs.members')
      expect(page).to have_css('#members.show')
      expect(page).to have_text('Robin Steward', count: 2)
      expect(page).to have_text(community_organizer_role.name)
      expect(page).to have_text(community_coordinator_role.name)
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/community_membership_multi_role_cards.png')
    expect(result[:mobile]).to end_with('docs/screenshots/mobile/community_membership_multi_role_cards.png')
  end

  private

  def screenshot_metadata(role:, flow:)
    {
      locale:,
      role:,
      feature_set: 'stacked_membership_roles',
      flow:,
      source_spec: self.class.metadata[:file_path]
    }
  end
end
