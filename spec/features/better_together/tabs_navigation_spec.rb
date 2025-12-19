# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'Tabbed navigation', :no_auth, :js do
  let(:locale) { I18n.default_locale }

  before do
    configure_host_platform
    host_platform = BetterTogether::Platform.find_by(host: true) ||
                    create(:better_together_platform, :host)
    platform_manager_role = BetterTogether::Role.find_or_create_by!(
      identifier: 'platform_manager',
      resource_type: 'BetterTogether::Platform'
    ) do |role|
      role.name = 'Platform Manager'
      role.protected = true
      role.position = 0
    end
    manage_platform_permission = BetterTogether::ResourcePermission.find_or_create_by!(
      identifier: 'manage_platform',
      resource_type: 'BetterTogether::Platform'
    ) do |permission|
      permission.action = 'manage'
      permission.target = 'platform'
      permission.protected = true
      permission.position = 6
    end
    platform_manager_role.assign_resource_permissions([manage_platform_permission.identifier])

    manager_user = BetterTogether::User.find_by(email: 'manager@example.test') ||
                   create(:better_together_user, :confirmed,
                          email: 'manager@example.test',
                          password: 'SecureTest123!@#')
    unless host_platform.person_platform_memberships.exists?(member: manager_user.person,
                                                            role: platform_manager_role)
      host_platform.person_platform_memberships.create!(
        member: manager_user.person,
        role: platform_manager_role
      )
    end
    Rails.cache.clear
    capybara_login_as_platform_manager

    create(:better_together_resource_permission,
           resource_type: 'BetterTogether::Community',
           action: 'view')
    create(:better_together_resource_permission,
           resource_type: 'BetterTogether::Community',
           action: 'manage')
    create(:better_together_resource_permission,
           resource_type: 'BetterTogether::Platform',
           action: 'view')
  end

  scenario 'updates the hash when switching resource type tabs' do
    visit better_together.resource_permissions_path(locale:)

    platform_tab_id = "resource-permissions-#{'BetterTogether::Platform'.parameterize}"
    find("button[data-bs-target=\"##{platform_tab_id}\"]").click

    expect(page).to have_current_path(
      /##{Regexp.escape(platform_tab_id)}\z/,
      url: true
    )
  end

  scenario 'updates the hash when switching nested action tabs' do
    visit better_together.resource_permissions_path(locale:)

    community_action_tab_id = "resource-permissions-#{'BetterTogether::Community'.parameterize}-action-manage"
    find("button[data-bs-target=\"##{community_action_tab_id}\"]").click

    expect(page).to have_current_path(
      /##{Regexp.escape(community_action_tab_id)}\z/,
      url: true
    )
  end

  scenario 'activates the nested action tab from the hash on load' do
    community_action_tab_id = "resource-permissions-#{'BetterTogether::Community'.parameterize}-action-manage"
    visit "#{better_together.resource_permissions_path(locale:)}##{community_action_tab_id}"

    expect(page).to have_css(
      "button##{community_action_tab_id}-tab.active"
    )
  end

  scenario 'shows all resource type panes when selecting all' do
    visit better_together.resource_permissions_path(locale:)

    all_tab_id = "resource-permissions-all"
    find("button[data-better_together--tabs-hash=\"##{all_tab_id}\"]").click

    community_tab_id = "resource-permissions-#{'BetterTogether::Community'.parameterize}"
    platform_tab_id = "resource-permissions-#{'BetterTogether::Platform'.parameterize}"

    expect(page).to have_css("##{community_tab_id}.show.active")
    expect(page).to have_css("##{platform_tab_id}.show.active")
  end

  scenario 'switches from all to a single resource type tab' do
    visit better_together.resource_permissions_path(locale:)

    all_tab_id = "resource-permissions-all"
    find("button[data-better_together--tabs-hash=\"##{all_tab_id}\"]").click

    platform_tab_id = "resource-permissions-#{'BetterTogether::Platform'.parameterize}"
    find("button[data-bs-target=\"##{platform_tab_id}\"]").click

    expect(page).to have_css("##{platform_tab_id}.show.active")
    expect(page).not_to have_css("##{all_tab_id}.show.active")
  end

  scenario 'shows all action panes within a resource type when selecting all' do
    visit better_together.resource_permissions_path(locale:)

    community_tab_id = "resource-permissions-#{'BetterTogether::Community'.parameterize}"
    action_all_tab_id = "#{community_tab_id}-action-all"
    manage_action_tab_id = "#{community_tab_id}-action-manage"
    view_action_tab_id = "#{community_tab_id}-action-view"

    within("##{community_tab_id}") do
      find("button[data-better_together--tabs-hash=\"##{action_all_tab_id}\"]").click
    end

    expect(page).to have_css("##{manage_action_tab_id}.show.active")
    expect(page).to have_css("##{view_action_tab_id}.show.active")
  end
end
