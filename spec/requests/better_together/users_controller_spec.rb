# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::UsersController' do
  # rubocop:disable Metrics/AbcSize
  def grant_platform_permission(user, permission_identifier)
    BetterTogether::AccessControlBuilder.seed_data

    host_platform = BetterTogether::Platform.find_by(host: true) ||
                    create(:better_together_platform, :host, community: user.person.community)
    membership = host_platform.person_platform_memberships.find_or_initialize_by(member: user.person)
    membership.role ||= create(:better_together_role, :platform_role)
    role = membership.role
    permission = BetterTogether::ResourcePermission.find_by!(identifier: permission_identifier)
    role.assign_resource_permissions([permission.identifier])
    membership.status = :active
    membership.save!
    user.person.touch
  end
  # rubocop:enable Metrics/AbcSize

  let(:locale) { I18n.default_locale }
  let(:manager) { create(:better_together_user, :confirmed, :platform_manager) }
  let(:user_admin) { create(:better_together_user, :confirmed, :platform_manager) }
  let(:target_user) { create(:better_together_user, :confirmed) }

  describe 'GET /:locale/.../host/users' do
    it 'renders not found for platform managers without explicit user-account permission' do
      sign_in manager

      get better_together.users_path(locale:)

      expect(response).to have_http_status(:not_found)
    end

    it 'renders index for explicit user-account admins' do
      grant_platform_permission(user_admin, 'manage_platform_users')
      sign_in user_admin

      get better_together.users_path(locale:)

      expect(response).to have_http_status(:ok)
      expect(assigns(:users)).to include(user_admin)
      expect(assigns(:users)).to be_present
    end

    it 'renders show for the current user without explicit user-account permission' do
      sign_in manager

      get better_together.user_path(locale:, id: manager.id)

      expect(response).to have_http_status(:ok)
    end

    it 'renders not found for other user accounts without explicit permission' do
      sign_in manager

      get better_together.user_path(locale:, id: target_user.id)

      expect(response).to have_http_status(:not_found)
    end

    it 'renders show for other user accounts when explicitly permitted' do
      grant_platform_permission(user_admin, 'manage_platform_users')
      sign_in user_admin

      get better_together.user_path(locale:, id: target_user.id)

      expect(response).to have_http_status(:ok)
    end
  end
end
