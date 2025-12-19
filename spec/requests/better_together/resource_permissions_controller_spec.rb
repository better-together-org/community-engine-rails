# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::ResourcePermissionsController', :as_platform_manager do
  let(:locale) { I18n.default_locale }

  describe 'GET /:locale/.../host/permissions' do
    it 'renders index' do
      get better_together.resource_permissions_path(locale:)
      expect(response).to have_http_status(:ok)
    end

    it 'groups permissions by resource type' do
      create(:better_together_resource_permission, resource_type: 'BetterTogether::Community')
      create(:better_together_resource_permission, resource_type: 'BetterTogether::Platform')

      get better_together.resource_permissions_path(locale:)

      expect(response.body).to include(BetterTogether::Community.model_name.human)
      expect(response.body).to include(BetterTogether::Platform.model_name.human)
    end

    it 'defaults to card view' do
      get better_together.resource_permissions_path(locale:)

      expect(response.body).to include('resource-permission-card-group')
      expect(response.body).not_to include('resource-permission-table-group')
    end

    it 'renders table view when preference is set' do
      post better_together.view_preferences_path(locale:), params: {
        key: 'resource_permissions_index',
        view_type: 'table',
        allowed: %w[card table]
      }

      get better_together.resource_permissions_path(locale:)

      expect(response.body).to include('resource-permission-table-group')
      expect(response.body).not_to include('resource-permission-card-group')
    end

    it 'renders view switcher with labels and no turbo prefetch' do
      get better_together.resource_permissions_path(locale:)

      expect(response.body).to include(I18n.t('better_together.view_switcher.change_view'))
      expect(response.body).to include(I18n.t('better_together.view_switcher.button_label',
                                             view: I18n.t('better_together.view_switcher.types.card')))
      expect(response.body).to include(I18n.t('better_together.view_switcher.button_label',
                                             view: I18n.t('better_together.view_switcher.types.table')))
      expect(response.body).to include('data-turbo-prefetch="false"')
    end

    it 'renders show for a permission' do
      permission = create(:better_together_resource_permission)
      get better_together.resource_permission_path(locale:, id: permission.slug)
      expect(response).to have_http_status(:ok)
    end

    it 'renders permission show metadata, role summary, and count' do
      permission = create(:better_together_resource_permission,
                          action: 'view',
                          target: 'metrics_dashboard',
                          resource_type: 'BetterTogether::Platform')
      role = create(:better_together_role, resource_type: 'BetterTogether::Platform', name: 'Platform Manager')
      role.assign_resource_permissions([permission.identifier])

      get better_together.resource_permission_path(locale:, id: permission.slug)

      expect(response.body).to include('metrics_dashboard')
      expect(response.body).to include(BetterTogether::Platform.model_name.human)
      expect(response.body).to include(I18n.t('better_together.resource_permissions.roles.label'))
      expect(response.body).to include('Platform Manager')
      expect(response.body).to include(I18n.t('better_together.resource_permissions.roles.count', count: 1))
    end
  end
end
