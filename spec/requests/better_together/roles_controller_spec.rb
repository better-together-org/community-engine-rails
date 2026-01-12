# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::RolesController', :as_platform_manager do
  let(:locale) { I18n.default_locale }

  describe 'GET /:locale/.../host/roles' do
    it 'renders index' do
      get better_together.roles_path(locale:)
      expect(response).to have_http_status(:ok)
    end

    it 'groups roles by resource type' do
      create(:better_together_role, resource_type: 'BetterTogether::Community', name: 'Community Manager')
      create(:better_together_role, resource_type: 'BetterTogether::Platform', name: 'Platform Manager')

      get better_together.roles_path(locale:)

      expect_html_contents(
        BetterTogether::Community.model_name.human,
        BetterTogether::Platform.model_name.human
      )
    end

    it 'shows permission labels in the list' do
      role = create(:better_together_role, resource_type: 'BetterTogether::Platform', name: 'Platform Manager')
      permission = create(:better_together_resource_permission,
                          action: 'view',
                          target: 'metrics_dashboard',
                          resource_type: 'BetterTogether::Platform')
      role.assign_resource_permissions([permission.identifier])

      get better_together.roles_path(locale:)

      expect_html_contents(
        'Permissions',
        permission.identifier.tr('_', ' ').humanize
      )
    end

    it 'defaults to card view' do
      get better_together.roles_path(locale:)

      expect(response.body).to include('role-card-group')
      expect(response.body).not_to include('role-table-group')
    end

    it 'renders view switcher with labels and no turbo prefetch' do
      get better_together.roles_path(locale:)

      expect_html_contents(
        I18n.t('better_together.view_switcher.change_view'),
        I18n.t('better_together.view_switcher.button_label',
               view: I18n.t('better_together.view_switcher.types.card')),
        I18n.t('better_together.view_switcher.button_label',
               view: I18n.t('better_together.view_switcher.types.table'))
      )
      expect(response.body).to include('data-turbo-prefetch="false"')
    end

    it 'renders table view when preference is set' do
      post better_together.view_preferences_path(locale:), params: {
        key: 'roles_index',
        view_type: 'table',
        allowed: %w[card table]
      }

      get better_together.roles_path(locale:)

      expect(response.body).to include('role-table-group')
      expect(response.body).not_to include('role-card-group')
    end

    it 'renders show for a role' do
      role = create(:better_together_role)
      get better_together.role_path(locale:, id: role.slug)
      expect(response).to have_http_status(:ok)
    end

    it 'renders role show metadata, permissions summary, and count' do
      role = create(:better_together_role, resource_type: 'BetterTogether::Platform', name: 'Platform Manager')
      permission = create(:better_together_resource_permission,
                          action: 'view',
                          target: 'metrics_dashboard',
                          resource_type: 'BetterTogether::Platform')
      role.assign_resource_permissions([permission.identifier])

      get better_together.role_path(locale:, id: role.slug)

      expect_html_contents(
        'Platform Manager',
        BetterTogether::Platform.model_name.human,
        I18n.t('better_together.roles.permissions.label'),
        permission.identifier.tr('_', ' ').humanize,
        I18n.t('better_together.roles.permissions.count', count: 1)
      )
    end
  end

  describe 'PATCH /:locale/.../host/roles/:id' do
    # rubocop:todo RSpec/MultipleExpectations
    it 'updates and redirects' do # rubocop:todo RSpec/MultipleExpectations
      # rubocop:enable RSpec/MultipleExpectations
      role = create(:better_together_role, protected: false)
      patch better_together.role_path(locale:, id: role.slug), params: {
        role: { name: 'New Name' }
      }
      expect(response).to have_http_status(:see_other)
      follow_redirect!
      expect(response).to have_http_status(:ok)
    end
  end
end
