# frozen_string_literal: true

# app/builders/better_together/access_control_builder.rb

module BetterTogether
  # Base builder to automate creation of important built-in data types
  class AccessControlBuilder < Builder
    class << self
      def seed_data
        build_community_roles
        build_community_resource_permissions
        build_platform_resource_permissions
        build_platform_roles
        assign_permissions_to_roles
      end

      def build_community_roles
        ::BetterTogether::Role.create!(community_role_attrs)
      end

      def build_community_resource_permissions
        ::BetterTogether::ResourcePermission.create!(community_resource_permission_attrs)
      end

      def build_platform_resource_permissions
        ::BetterTogether::ResourcePermission.create!(platform_resource_permission_attrs)
      end

      def build_platform_roles
        ::BetterTogether::Role.create!(platform_role_attrs)
      end

      # Clear existing data - Use with caution!
      def clear_existing
        ::BetterTogether::RoleResourcePermission.delete_all
        ::BetterTogether::Role.delete_all
        ::BetterTogether::ResourcePermission.delete_all
      end

      def assign_permissions_to_roles
        assign_community_permissions_to_roles
        assign_platform_permissions_to_roles
      end

      def assign_community_permissions_to_roles
        # Mapping of community roles to community permissions
        community_role_permissions = {
          'community_member' => %w(read_community list_community),
          'community_contributor' => %w(read_community list_community create_community),
          'community_facilitator' => %w(read_community list_community create_community update_community delete_community),
          'community_coordinator' => %w(read_community list_community create_community update_community delete_community manage_community_settings manage_community_content manage_community_roles manage_community_notifications),
          'community_content_curator' => %w(read_community list_community create_community update_community delete_community manage_community_content),
          'community_strategist' => %w(read_community list_community create_community update_community delete_community manage_community_roles),
          'community_legal_advisor' => %w(read_community list_community create_community update_community delete_community manage_community_settings),
          'community_governance_council' => %w(read_community list_community create_community update_community delete_community manage_community_roles),
          # Add more mappings as needed...
        }

        assign_permissions(community_role_permissions, 'BetterTogether::Community')
      end

      def assign_platform_permissions_to_roles
        # Mapping of platform roles to platform permissions
        platform_role_permissions = {
          'platform_manager' => %w(read_platform list_platform create_platform update_platform delete_platform manage_platform_api manage_platform_data_privacy manage_platform_database manage_platform_deployment manage_platform_roles manage_platform_security manage_platform_settings manage_platform_users view_platform_analytics view_platform_logs),
          'platform_infrastructure_architect' => %w(read_platform list_platform create_platform update_platform delete_platform manage_platform_api manage_platform_data_privacy manage_platform_database manage_platform_deployment manage_platform_roles manage_platform_security manage_platform_settings manage_platform_users view_platform_analytics view_platform_logs),
          'platform_tech_support' => %w(read_platform list_platform create_platform update_platform delete_platform manage_platform_api manage_platform_data_privacy manage_platform_database manage_platform_deployment manage_platform_roles manage_platform_security manage_platform_settings manage_platform_users view_platform_analytics view_platform_logs),
          'platform_developer' => %w(read_platform list_platform create_platform update_platform delete_platform manage_platform_api manage_platform_data_privacy manage_platform_database manage_platform_deployment manage_platform_roles manage_platform_security manage_platform_settings manage_platform_users view_platform_analytics view_platform_logs),
          'platform_quality_assurance_lead' => %w(read_platform list_platform create_platform update_platform delete_platform manage_platform_api manage_platform_data_privacy manage_platform_database manage_platform_deployment manage_platform_roles manage_platform_security manage_platform_settings manage_platform_users view_platform_analytics view_platform_logs),
          'platform_accessibility_officer' => %w(read_platform list_platform create_platform update_platform delete_platform manage_platform_api manage_platform_data_privacy manage_platform_database manage_platform_deployment manage_platform_roles manage_platform_security manage_platform_settings manage_platform_users view_platform_analytics view_platform_logs),
          # Add more mappings as needed...
        }

        assign_permissions(platform_role_permissions, 'BetterTogether::Platform')
      end

      def assign_permissions(role_permissions, resource_type)
        role_permissions.each do |role_identifier, permission_identifiers|
          role = ::BetterTogether::Role.find_by(identifier: role_identifier, resource_type:)
          next unless role
          role.assign_resource_permissions(permission_identifiers)
        end
      end

      def community_role_attrs
        [
          {
            protected: true,
            identifier: 'community_member',
            position: 0,
            resource_type: 'BetterTogether::Community',
            name: 'Community Member',
            description: 'Basic role for general community interaction, focusing on content consumption and participation in discussions.'
          },
          {
            protected: true,
            identifier: 'community_contributor',
            position: 1,
            resource_type: 'BetterTogether::Community',
            name: 'Community Contributor',
            description: 'Empowers users to create and share content, fostering a creative and active community environment.'
          },
          {
            protected: true,
            identifier: 'community_facilitator',
            position: 2,
            resource_type: 'BetterTogether::Community',
            name: 'Community Facilitator',
            description: 'Guides discussions and ensures inclusivity, acting as a mediator to foster a positive community environment.'
          },
          {
            protected: true,
            identifier: 'community_coordinator',
            position: 3,
            resource_type: 'BetterTogether::Community',
            name: 'Community Coordinator',
            description: 'Manages community engagement and events, enhancing interaction and supporting sub-community initiatives.'
          },
          {
            protected: true,
            identifier: 'community_content_curator',
            position: 4,
            resource_type: 'BetterTogether::Community',
            name: 'Community Content Curator',
            description: 'Manages the creation and curation of educational and engaging content, ensuring it meets community needs and aligns with platform objectives.'
          },
          {
            protected: true,
            identifier: 'community_strategist',
            position: 5,
            resource_type: 'BetterTogether::Community',
            name: 'Community Strategist',
            description: 'Focuses on aligning community activities with broader platform goals and managing long-term strategic planning.'
          },
          {
            protected: true,
            identifier: 'community_legal_advisor',
            position: 6,
            resource_type: 'BetterTogether::Community',
            name: 'Community Legal Advisor',
            description: 'Advises on legal matters pertaining to community interactions and content, ensuring compliance with laws and platform policies.'
          },
          {
            protected: true,
            identifier: 'community_governance_council',
            position: 7,
            resource_type: 'BetterTogether::Community',
            name: 'Community Governance Council',
            description: 'Oversees platform governance, ensuring that decisions reflect community interests and uphold ethical standards.'
          }
        ]

      end

      def community_resource_permission_attrs
        [
          { action: 'create', target: 'community', resource_type: 'BetterTogether::Community', identifier: 'create_community', protected: true, position: 0 },
          { action: 'read', target: 'community', resource_type: 'BetterTogether::Community', identifier: 'read_community', protected: true, position: 1 },
          { action: 'update', target: 'community', resource_type: 'BetterTogether::Community', identifier: 'update_community', protected: true, position: 2 },
          { action: 'delete', target: 'community', resource_type: 'BetterTogether::Community', identifier: 'delete_community', protected: true, position: 3 },
          { action: 'list', target: 'community', resource_type: 'BetterTogether::Community', identifier: 'list_community', protected: true, position: 4 },
          { action: 'manage', target: 'settings', resource_type: 'BetterTogether::Community', identifier: 'manage_community_settings', protected: true, position: 7 },
          { action: 'manage', target: 'content', resource_type: 'BetterTogether::Community', identifier: 'manage_community_content', protected: true, position: 8 },
          { action: 'manage', target: 'roles', resource_type: 'BetterTogether::Community', identifier: 'manage_community_roles', protected: true, position: 9 },
          { action: 'manage', target: 'notifications', resource_type: 'BetterTogether::Community', identifier: 'manage_community_notifications', protected: true, position: 10 }
        ]
      end

      def platform_role_attrs
        [
          {
            protected: true,
            identifier: 'platform_manager',
            position: 0,
            resource_type: 'BetterTogether::Platform',
            name: 'Platform Manager',
            description: 'Manages daily operations and technical updates, ensuring the platform remains stable and responsive to user needs.'
          },
          {
            protected: true,
            identifier: 'platform_infrastructure_architect',
            position: 1,
            resource_type: 'BetterTogether::Platform',
            name: 'Platform Infrastructure Architect',
            description: 'Designs and manages the platform\'s IT infrastructure, ensuring scalability, security, and efficient performance.'
          },
          {
            protected: true,
            identifier: 'platform_tech_support',
            position: 2,
            resource_type: 'BetterTogether::Platform',
            name: 'Platform Tech Support',
            description: 'Provides ongoing technical support and troubleshooting, ensuring that technical issues are resolved quickly.'
          },
          {
            protected: true,
            identifier: 'platform_developer',
            position: 3,
            resource_type: 'BetterTogether::Platform',
            name: 'Platform Developer',
            description: 'Develops new features and maintains the existing codebase, integrating community contributions and improving platform functionalities.'
          },
          {
            protected: true,
            identifier: 'platform_quality_assurance_lead',
            position: 4,
            resource_type: 'BetterTogether::Platform',
            name: 'Platform Quality Assurance Lead',
            description: 'Ensures that all platform updates and features pass rigorous testing, maintaining high standards for reliability and performance.'
          },
          {
            protected: true,
            identifier: 'platform_accessibility_officer',
            position: 5,
            resource_type: 'BetterTogether::Platform',
            name: 'Platform Accessibility Officer',
            description: 'Ensures that the platform is accessible to all users, advocating for and implementing best practices in accessibility.'
          }
        ]
      end

      def platform_resource_permission_attrs
        [
          { action: 'create', target: 'platform', resource_type: 'BetterTogether::Platform', identifier: 'create_platform', protected: true, position: 0 },
          { action: 'read', target: 'platform', resource_type: 'BetterTogether::Platform', identifier: 'read_platform', protected: true, position: 1 },
          { action: 'update', target: 'platform', resource_type: 'BetterTogether::Platform', identifier: 'update_platform', protected: true, position: 2 },
          { action: 'delete', target: 'platform', resource_type: 'BetterTogether::Platform', identifier: 'delete_platform', protected: true, position: 3 },
          { action: 'list', target: 'platform', resource_type: 'BetterTogether::Platform', identifier: 'list_platform', protected: true, position: 4 },
          { action: 'manage', target: 'platform_api', resource_type: 'BetterTogether::Platform', identifier: 'manage_platform_api', protected: true, position: 5 },
          { action: 'manage', target: 'platform_data_privacy', resource_type: 'BetterTogether::Platform', identifier: 'manage_platform_data_privacy', protected: true, position: 6 },
          { action: 'manage', target: 'platform_database', resource_type: 'BetterTogether::Platform', identifier: 'manage_platform_database', protected: true, position: 7 },
          { action: 'manage', target: 'platform_deployment', resource_type: 'BetterTogether::Platform', identifier: 'manage_platform_deployment', protected: true, position: 8 },
          { action: 'manage', target: 'platform_roles', resource_type: 'BetterTogether::Platform', identifier: 'manage_platform_roles', protected: true, position: 9 },
          { action: 'manage', target: 'platform_security', resource_type: 'BetterTogether::Platform', identifier: 'manage_platform_security', protected: true, position: 10 },
          { action: 'manage', target: 'platform_settings', resource_type: 'BetterTogether::Platform', identifier: 'manage_platform_settings', protected: true, position: 11 },
          { action: 'manage', target: 'platform_users', resource_type: 'BetterTogether::Platform', identifier: 'manage_platform_users', protected: true, position: 12 },
          { action: 'view', target: 'platform_analytics', resource_type: 'BetterTogether::Platform', identifier: 'view_platform_analytics', protected: true, position: 13 },
          { action: 'view', target: 'platform_logs', resource_type: 'BetterTogether::Platform', identifier: 'view_platform_logs', protected: true, position: 14 }
        ]
      end
    end
  end
end
