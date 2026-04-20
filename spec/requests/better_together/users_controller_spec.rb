# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::UsersController' do
  def grant_platform_permission(user, permission_identifier)
    BetterTogether::AccessControlBuilder.seed_data

    host_platform = BetterTogether::Platform.find_by(host: true) ||
                    create(:better_together_platform, :host, community: user.person.community)
    role = create(:better_together_role, :platform_role)
    permission = BetterTogether::ResourcePermission.find_by!(identifier: permission_identifier)
    role.assign_resource_permissions([permission.identifier])
    host_platform.person_platform_memberships.find_or_create_by!(member: user.person, role:)
  end

  let(:locale) { I18n.default_locale }
  let(:manager) { create(:better_together_user, :confirmed, :platform_manager) }

  before do
    grant_platform_permission(manager, 'manage_platform_users')
    sign_in manager
  end

  describe 'GET /:locale/.../host/users' do
    it 'renders index' do
      get better_together.users_path(locale:)
      expect(response).to have_http_status(:ok)
    end

    it 'renders show for the current user' do
      get better_together.user_path(locale:, id: manager.id)
      expect(response).to have_http_status(:ok)
    end
  end
end
