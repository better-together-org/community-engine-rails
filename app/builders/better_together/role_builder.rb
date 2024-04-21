# frozen_string_literal: true

# app/builders/better_together/role_builder.rb

module BetterTogether
  # Base builder to automate creation of important built-in data types
  class RoleBuilder < Builder
    class << self
      def seed_data
        build_platform_resource_permissions
        build_platform_roles
      end

      def build_platform_resource_permissions
        ::BetterTogether::ResourcePermission.create(platform_resource_permission_attrs)
      end

      def build_platform_roles
        roles = platform_role_attrs

        ::BetterTogether::Role.create(roles)
      rescue => e
        e
      end

      # Clear existing data - Use with caution!
      def clear_existing
        ::BetterTogether::Role.delete_all
        ::BetterTogether::ResourcePermission.delete_all
      end

      def platform_role_attrs
        [
          {
            protected: true,
            identifier: 'viewer',
            position: 0,
            resource_class: '::BetterTogether::Platform',
            name: 'Viewer',
            description: 'Can view content and participate in discussions. Access to publicly available information and forums.'
          },
          {
            protected: true,
            identifier: 'contributor',
            position: 1,
            resource_class: '::BetterTogether::Platform',
            name: 'Contributor',
            description: 'Can create and edit their own posts, comments, and discussions. Access to content creation tools and personal profile editing.'
          },
          {
            protected: true,
            identifier: 'moderator',
            position: 2,
            resource_class: '::BetterTogether::Platform',
            name: 'Moderator',
            description: 'Can moderate discussions, edit or delete any user-generated content, and handle user reports. Access to moderation tools and content management.'
          },
          {
            protected: true,
            identifier: 'community_manager',
            position: 3,
            resource_class: '::BetterTogether::Platform',
            name: 'Community Manager',
            description: 'Manages user roles, community engagement, and sub-communities. Access to user management (except admin roles), community settings, and analytics.'
          },
          {
            protected: true,
            identifier: 'developer',
            position: 4,
            resource_class: '::BetterTogether::Platform',
            name: 'Developer',
            description: 'Responsible for system maintenance, updates, and technical issues. Access to backend, server, and database management.'
          },
          {
            protected: true,
            identifier: 'administrator',
            position: 5,
            resource_class: '::BetterTogether::Platform',
            name: 'Administrator',
            description: 'Full control over platform settings, user management, and strategic planning. Access to all 
              administrative settings and platform data.'
          },
          {
            protected: true,
            identifier: 'super_administrator',
            position: 6,
            resource_class: '::BetterTogether::Platform',
            name: 'Super Administrator',
            description: 'Ultimate authority over platform decisions, admin account management, and strategic direction.
               Full system access and ownership control.'
          }
        ]
      end

      def platform_resource_permission_attrs
        [
          { action: 'create', resource_class: '::BetterTogether::Platform', identifier: 'create_better_together_platform', protected: true },
          { action: 'read', resource_class: '::BetterTogether::Platform', identifier: 'read_better_together_platform', protected: true },
          { action: 'write', resource_class: '::BetterTogether::Platform', identifier: 'write_better_together_platform', protected: true },
          { action: 'delete', resource_class: '::BetterTogether::Platform', identifier: 'delete_better_together_platform', protected: true },
          { action: 'manage_users', resource_class: '::BetterTogether::Platform', identifier: 'manage_users_better_together_platform', protected: true },
          { action: 'manage_roles', resource_class: '::BetterTogether::Platform', identifier: 'manage_roles_better_together_platform', protected: true },
          { action: 'access_backend', resource_class: '::BetterTogether::Platform', identifier: 'access_backend_better_together_platform', protected: true },
          { action: 'manage_settings', resource_class: '::BetterTogether::Platform', identifier: 'manage_settings_better_together_platform', protected: true }
        ]
      end
    end
  end
end
