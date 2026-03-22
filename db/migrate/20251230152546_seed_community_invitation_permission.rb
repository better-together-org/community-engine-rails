# frozen_string_literal: true

# Migration to seed the invite_community_members permission and assign it to appropriate community roles
class SeedCommunityInvitationPermission < ActiveRecord::Migration[7.2]
  def up
    puts 'Seeding community invitation permission and role assignments...'

    load BetterTogether::Engine.root.join('lib', 'tasks', 'better_together', 'seed_rbac_and_navigation.rake')

    begin
      Rake::Task['better_together:seed:community_invitation_permission'].invoke
    rescue RuntimeError
      Rake::Task['app:better_together:seed:community_invitation_permission'].invoke
    end
  end

  def down
    # Remove the permission assignment (not the permission itself, as it may be in use)
    # This is a reversible migration for development/testing purposes
    permission = BetterTogether::ResourcePermission.find_by(identifier: 'invite_community_members')
    return unless permission

    remove_permission_from_roles(permission)
  end

  private

  def remove_permission_from_roles(permission)
    role_identifiers = %w[community_facilitator community_coordinator community_governance_council]

    BetterTogether::RoleResourcePermission.where(
      role_id: BetterTogether::Role.where(identifier: role_identifiers).pluck(:id),
      resource_permission_id: permission.id
    ).delete_all
  end
end
