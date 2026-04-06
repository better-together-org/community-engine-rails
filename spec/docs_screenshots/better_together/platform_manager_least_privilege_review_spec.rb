# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for reduced platform-manager access',
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let(:locale) { I18n.default_locale }
  let(:password) { 'SecureTest123!@#' }
  let!(:host_platform) { configure_host_platform }
  let!(:other_platform) { create(:better_together_platform) }
  let!(:dashboard_manager) do
    find_or_create_test_user("dashboard-manager-#{SecureRandom.hex(4)}@example.test", password, :platform_manager)
  end
  let!(:conversation_manager) do
    create(:user, :confirmed,
           email: "conversation-manager-#{SecureRandom.hex(4)}@example.test",
           password:,
           person_attributes: { name: 'Platform Steward' })
  end
  let!(:regular_user) do
    create(:user, :confirmed, email: "reduced-access-member-#{SecureRandom.hex(4)}@example.test", password:,
                              person_attributes: { name: 'Regular Member' })
  end
  let!(:opted_in_person) do
    create(:better_together_person, preferences: { receive_messages_from_members: true }, name: "Opted In O'Reilly")
  end
  let!(:non_opted_person) { create(:better_together_person, name: "Non Opted O'Neil") }
  let!(:other_platform_opted_in_person) do
    create(:better_together_person, preferences: { receive_messages_from_members: true }, name: 'Other Platform Person')
  end
  let!(:host_only_opted_in_person) do
    create(:better_together_person, preferences: { receive_messages_from_members: true }, name: 'Host Community Person')
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    BetterTogether::AccessControlBuilder.seed_data

    create(:better_together_person_platform_membership,
           member: conversation_manager.person,
           joinable: host_platform,
           role: role_with_permissions('manage_platform', 'list_person'))
    create(:better_together_person_platform_membership, member: regular_user.person, joinable: host_platform)
    create(:better_together_person_platform_membership, member: opted_in_person, joinable: host_platform)
    create(:better_together_person_platform_membership, member: non_opted_person, joinable: host_platform)
    create(:better_together_person_platform_membership, member: other_platform_opted_in_person, joinable: other_platform)
    create(:better_together_person_community_membership, member: host_only_opted_in_person, joinable: host_platform.community)

    reset_permission_cache(conversation_manager)
  end

  after do
    Current.platform = nil
  end

  it 'captures the user-surface fallback for default platform managers' do
    result = BetterTogether::CapybaraScreenshotEngine.capture(
      'platform_manager_user_surface_fallback',
      device: :both,
      metadata: screenshot_metadata(flow: 'user_account_surface_fallback'),
      callouts: [
        {
          selector: 'main h1',
          title: 'User-account surface stays unavailable by default',
          bullets: [
            'Default platform-management access does not expose a usable host user directory.',
            'Without explicit account-admin authority, the user surface falls back to a not-found page in this flow.',
            'A broader user-account surface still requires an explicit manage_platform_users grant.'
          ]
        }
      ]
    ) do
      login_as(dashboard_manager, scope: :user)
      visit better_together.users_path(locale:)

      expect(page).to have_current_path(better_together.users_path(locale:), wait: 10)
      expect(page).to have_text('404 - Page Not Found')
      expect(page).to have_text('Go to Home')
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/platform_manager_user_surface_fallback.png')
    expect(result[:mobile]).to end_with('docs/screenshots/mobile/platform_manager_user_surface_fallback.png')
  end

  it 'captures the conversation composer with a scoped participant list' do
    expected_allowed_labels = [
      conversation_manager.person.select_option_title,
      opted_in_person.select_option_title,
      host_only_opted_in_person.select_option_title
    ]
    withheld_labels = [
      regular_user.person.select_option_title,
      non_opted_person.select_option_title,
      other_platform_opted_in_person.select_option_title
    ]

    result = BetterTogether::CapybaraScreenshotEngine.capture(
      'platform_manager_scoped_conversation_participants',
      device: :both,
      metadata: screenshot_metadata(flow: 'conversation_participant_scope'),
      callouts: [
        {
          selector: 'select[name="conversation[participant_ids][]"]',
          title: 'Scoped conversation discovery for platform managers',
          bullets: [
            "Available in picker: #{expected_allowed_labels.join(', ')}",
            "Withheld from picker: #{withheld_labels.join(', ')}",
            'Broad platform-management access does not reopen non-opted-in or other-platform participant discovery.'
          ]
        }
      ]
    ) do
      login_as(conversation_manager, scope: :user)
      visit better_together.new_conversation_path(locale:)

      expect(page).to have_css('#new_conversation_form')
      expect(page).to have_css('select[name="conversation[participant_ids][]"]', visible: :all)

      allowed_labels = participant_option_labels

      expect(allowed_labels).to include(*expected_allowed_labels)
      expect(allowed_labels).not_to include(*withheld_labels)
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/platform_manager_scoped_conversation_participants.png')
    expect(result[:mobile]).to end_with('docs/screenshots/mobile/platform_manager_scoped_conversation_participants.png')
  end

  private

  def role_with_permissions(*permission_identifiers)
    role = create(:better_together_role, :platform_role)
    role.assign_resource_permissions(permission_identifiers)
    role
  end

  def participant_option_labels
    page.evaluate_script(<<~JS)
      (function() {
        const select = document.querySelector('select[name="conversation[participant_ids][]"]');
        if (!select) return [];
        return Array.from(select.options).map((option) => option.text.trim()).filter(Boolean);
      })();
    JS
  end

  def reset_permission_cache(user)
    Rails.cache.delete_matched("better_together/member/#{user.person.class.name}/#{user.person.id}/*")
    user.reload
    user.person.reload
  end

  def screenshot_metadata(flow:)
    {
      locale:,
      role: 'platform_manager',
      feature_set: 'platform_manager_least_privilege_review',
      flow:,
      source_spec: self.class.metadata[:file_path]
    }
  end
end
