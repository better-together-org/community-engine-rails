# frozen_string_literal: true

# app/builders/better_together/access_control_builder.rb

module BetterTogether
  # Base builder to automate creation of important built-in data types
  class AccessControlBuilder < Builder # rubocop:todo Metrics/ClassLength
    class << self
      def seed_data
        build_community_roles
        build_community_resource_permissions
        build_platform_resource_permissions
        build_platform_roles
        build_person_resource_permissions
        assign_permissions_to_roles
      end

      def build_community_roles
        community_role_attrs.each do |attrs|
          # Idempotent: find by unique identifier and update attributes if needed
          role = ::BetterTogether::Role.find_or_initialize_by(identifier: attrs[:identifier])
          role.assign_attributes(attrs)
          role.save! if role.changed?
        end
      end

      def build_community_resource_permissions
        community_resource_permission_attrs.each do |attrs|
          perm = ::BetterTogether::ResourcePermission.find_or_initialize_by(identifier: attrs[:identifier])
          perm.assign_attributes(attrs)
          perm.save! if perm.changed?
        end
      end

      def build_platform_resource_permissions
        platform_resource_permission_attrs.each do |attrs|
          perm = ::BetterTogether::ResourcePermission.find_or_initialize_by(identifier: attrs[:identifier])
          perm.assign_attributes(attrs)
          perm.save! if perm.changed?
        end
      end

      def build_platform_roles
        platform_role_attrs.each do |attrs|
          role = ::BetterTogether::Role.find_or_initialize_by(identifier: attrs[:identifier])
          role.assign_attributes(attrs)
          role.save! if role.changed?
        end
      end

      def build_person_resource_permissions
        person_resource_permission_attrs.each do |attrs|
          perm = ::BetterTogether::ResourcePermission.find_or_initialize_by(identifier: attrs[:identifier])
          perm.assign_attributes(attrs)
          perm.save! if perm.changed?
        end
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
        assign_person_permissions_to_roles
      end

      def assign_community_permissions_to_roles # rubocop:todo Metrics/MethodLength
        # Mapping of community roles to community permissions
        community_role_permissions = {
          'community_member' => %w[
            read_community
            list_community
          ],
          'community_contributor' => %w[
            read_community
            list_community
            create_community
          ],
          'community_facilitator' => %w[
            read_community
            list_community
            create_community
            update_community
            delete_community
            invite_community_members
          ],
          'community_coordinator' => %w[
            read_community
            list_community
            create_community
            update_community
            delete_community
            manage_community_settings
            manage_community_content
            manage_community_roles
            manage_community_notifications
            invite_community_members
          ],
          'community_content_curator' => %w[
            read_community
            list_community
            create_community
            update_community
            delete_community
            manage_community_content
          ],
          'community_strategist' => %w[
            read_community
            list_community
            create_community
            update_community
            delete_community
            manage_community_roles
          ],
          'community_legal_advisor' => %w[
            read_community
            list_community
            create_community
            update_community
            delete_community
            manage_community_settings
          ],
          'community_governance_council' => %w[
            read_community
            list_community
            create_community
            update_community
            delete_community
            manage_community_roles
            invite_community_members
          ],
          'platform_manager' => %w[
            read_community
            list_community
            create_community
            update_community
            delete_community
            manage_community_settings
            manage_community_content
            manage_community_roles
            manage_community_notifications
            invite_community_members
          ]
          # Add more mappings as needed...
        }

        assign_permissions(community_role_permissions)
      end

      def assign_platform_permissions_to_roles # rubocop:todo Metrics/MethodLength
        # Mapping of platform roles to platform permissions
        platform_role_permissions = {
          'platform_manager' => %w[
            read_platform
            list_platform
            create_platform
            update_platform
            delete_platform
            manage_platform
            manage_platform_api
            manage_platform_data_privacy
            manage_platform_database
            manage_platform_deployment
            manage_platform_roles
            manage_platform_security
            manage_platform_settings
            manage_platform_users
            view_metrics_dashboard
            create_metrics_reports
            download_metrics_reports
            view_platform_logs
          ],
          'platform_analytics_viewer' => %w[
            view_metrics_dashboard
            create_metrics_reports
            download_metrics_reports
          ],
          'platform_infrastructure_architect' => %w[
            read_platform
            list_platform
            create_platform
            update_platform
            delete_platform
            manage_platform
            manage_platform_api
            manage_platform_data_privacy
            manage_platform_database
            manage_platform_deployment
            manage_platform_roles
            manage_platform_security
            manage_platform_settings
            view_metrics_dashboard
            create_metrics_reports
            download_metrics_reports
            view_platform_logs
          ],
          'platform_tech_support' => %w[
            read_platform
            list_platform
            create_platform
            update_platform
            delete_platform
            manage_platform
            manage_platform_api
            manage_platform_data_privacy
            manage_platform_database
            manage_platform_deployment
            manage_platform_roles
            manage_platform_security
            manage_platform_settings
            manage_platform_users
            view_metrics_dashboard
            create_metrics_reports
            download_metrics_reports
            view_platform_logs
          ],
          'platform_developer' => %w[
            read_platform
            list_platform
            create_platform
            update_platform
            delete_platform
            manage_platform
            manage_platform_api
            manage_platform_data_privacy
            manage_platform_database
            manage_platform_deployment
            manage_platform_roles
            manage_platform_security
            manage_platform_settings
            manage_platform_users
            view_metrics_dashboard
            create_metrics_reports
            download_metrics_reports
            view_platform_logs
          ],
          'platform_quality_assurance_lead' => %w[
            read_platform
            list_platform
            create_platform
            update_platform
            delete_platform
            manage_platform
            manage_platform_api
            manage_platform_data_privacy
            manage_platform_database
            manage_platform_deployment
            manage_platform_roles
            manage_platform_security
            manage_platform_settings
            manage_platform_users
            view_metrics_dashboard
            create_metrics_reports
            download_metrics_reports
            view_platform_logs
          ],
          'platform_accessibility_officer' => %w[
            read_platform
            list_platform
            create_platform
            update_platform
            delete_platform
            manage_platform
            manage_platform_api
            manage_platform_data_privacy
            manage_platform_database
            manage_platform_deployment
            manage_platform_roles
            manage_platform_security
            manage_platform_settings
            manage_platform_users
            view_metrics_dashboard
            create_metrics_reports
            download_metrics_reports
            view_platform_logs
          ]
          # Add more mappings as needed...
        }

        assign_permissions(platform_role_permissions)
      end

      def assign_person_permissions_to_roles # rubocop:todo Metrics/MethodLength
        # Mapping of platform roles to platform permissions
        person_role_permissions = {
          'platform_manager' => %w[
            read_person
            list_person
            create_person
            update_person
            delete_person
          ],
          'platform_infrastructure_architect' => %w[
            read_person
            list_person
            create_person
            update_person
          ],
          'platform_tech_support' => %w[
            read_person
            list_person
            create_person
            update_person
          ],
          'platform_developer' => %w[
            read_person
            list_person
            create_person
            update_person
          ],
          'platform_quality_assurance_lead' => %w[
            read_person
            list_person
            create_person
            update_person
          ],
          'platform_accessibility_officer' => %w[
            read_person
            list_person
            create_person
            update_person
          ]
          # Add more mappings as needed...
        }

        assign_permissions(person_role_permissions)
      end

      def assign_permissions(role_permissions)
        role_permissions.each do |role_identifier, permission_identifiers|
          role = ::BetterTogether::Role.find_by(identifier: role_identifier)
          next unless role

          role.assign_resource_permissions(permission_identifiers)
        end
      end

      def community_role_attrs # rubocop:todo Metrics/MethodLength
        [
          {
            protected: true,
            identifier: 'community_member',
            position: 0,
            resource_type: 'BetterTogether::Community',
            name: 'Community Member',
            description: 'Basic role for general community interaction, focusing on content consumption and ' \
                         'participation in discussions.'
          },
          {
            protected: true,
            identifier: 'community_contributor',
            position: 1,
            resource_type: 'BetterTogether::Community',
            name: 'Community Contributor',
            description: 'Empowers users to create and share content, fostering a creative and active community ' \
                         'environment.'
          },
          {
            protected: true,
            identifier: 'community_facilitator',
            position: 2,
            resource_type: 'BetterTogether::Community',
            name: 'Community Facilitator',
            description: 'Guides discussions and ensures inclusivity, acting as a mediator to foster a positive ' \
                         'community environment.'
          },
          {
            protected: true,
            identifier: 'community_coordinator',
            position: 3,
            resource_type: 'BetterTogether::Community',
            name: 'Community Coordinator',
            description: 'Manages community engagement and events, enhancing interaction and supporting ' \
                         'sub-community initiatives.'
          },
          {
            protected: true,
            identifier: 'community_content_curator',
            position: 4,
            resource_type: 'BetterTogether::Community',
            name: 'Community Content Curator',
            description: 'Manages the creation and curation of educational and engaging content, ensuring it meets ' \
                         'community needs and aligns with platform objectives.'
          },
          {
            protected: true,
            identifier: 'community_strategist',
            position: 5,
            resource_type: 'BetterTogether::Community',
            name: 'Community Strategist',
            description: 'Focuses on aligning community activities with broader platform goals and managing ' \
                         'long-term strategic planning.'
          },
          {
            protected: true,
            identifier: 'community_legal_advisor',
            position: 6,
            resource_type: 'BetterTogether::Community',
            name: 'Community Legal Advisor',
            description: 'Advises on legal matters pertaining to community interactions and content, ensuring ' \
                         'compliance with laws and platform policies.'
          },
          {
            protected: true,
            identifier: 'community_governance_council',
            position: 7,
            resource_type: 'BetterTogether::Community',
            name: 'Community Governance Council',
            description: 'Oversees platform governance, ensuring that decisions reflect community interests and ' \
                         'uphold ethical standards.'
          }
        ]
      end

      def community_resource_permission_attrs # rubocop:todo Metrics/MethodLength
        [
          {
            action: 'create', target: 'community', resource_type: 'BetterTogether::Community',
            identifier: 'create_community', protected: true, position: 0
          },
          {
            action: 'read', target: 'community', resource_type: 'BetterTogether::Community',
            identifier: 'read_community', protected: true, position: 1
          },
          {
            action: 'update', target: 'community', resource_type: 'BetterTogether::Community',
            identifier: 'update_community', protected: true, position: 2
          },
          {
            action: 'delete', target: 'community', resource_type: 'BetterTogether::Community',
            identifier: 'delete_community', protected: true, position: 3
          },
          {
            action: 'list', target: 'community', resource_type: 'BetterTogether::Community',
            identifier: 'list_community', protected: true, position: 4
          },
          {
            action: 'manage', target: 'settings', resource_type: 'BetterTogether::Community',
            identifier: 'manage_community_settings', protected: true, position: 7
          },
          {
            action: 'manage', target: 'content', resource_type: 'BetterTogether::Community',
            identifier: 'manage_community_content', protected: true, position: 8
          },
          {
            action: 'manage', target: 'roles', resource_type: 'BetterTogether::Community',
            identifier: 'manage_community_roles', protected: true, position: 9
          },
          {
            action: 'manage', target: 'notifications', resource_type: 'BetterTogether::Community',
            identifier: 'manage_community_notifications', protected: true, position: 10
          },
          {
            action: 'manage', target: 'member_invitations', resource_type: 'BetterTogether::Community',
            identifier: 'invite_community_members', protected: true, position: 11
          }
        ]
      end

      def platform_role_attrs # rubocop:todo Metrics/MethodLength
        [
          {
            protected: true,
            identifier: 'platform_manager',
            position: 0,
            resource_type: 'BetterTogether::Platform',
            name: 'Platform Manager',
            description: 'Manages daily operations and technical updates, ensuring the platform remains stable and ' \
                         'responsive to user needs.'
          },
          {
            protected: true,
            identifier: 'platform_infrastructure_architect',
            position: 1,
            resource_type: 'BetterTogether::Platform',
            name: 'Platform Infrastructure Architect',
            description: 'Designs and manages the platform\'s IT infrastructure, ensuring scalability, security, ' \
                         'and efficient performance.'
          },
          {
            protected: true,
            identifier: 'platform_tech_support',
            position: 2,
            resource_type: 'BetterTogether::Platform',
            name: 'Platform Tech Support',
            description: 'Provides ongoing technical support and troubleshooting, ensuring that technical issues ' \
                         'are resolved quickly.'
          },
          {
            protected: true,
            identifier: 'platform_developer',
            position: 3,
            resource_type: 'BetterTogether::Platform',
            name: 'Platform Developer',
            description: 'Develops new features and maintains the existing codebase, integrating community ' \
                         'contributions and improving platform functionalities.'
          },
          {
            protected: true,
            identifier: 'platform_quality_assurance_lead',
            position: 4,
            resource_type: 'BetterTogether::Platform',
            name: 'Platform Quality Assurance Lead',
            description: 'Ensures that all platform updates and features pass rigorous testing, maintaining high ' \
                         'standards for reliability and performance.'
          },
          {
            protected: true,
            identifier: 'platform_accessibility_officer',
            position: 5,
            resource_type: 'BetterTogether::Platform',
            name: 'Platform Accessibility Officer',
            description: 'Ensures that the platform is accessible to all users, advocating for and implementing ' \
                         'best practices in accessibility.'
          },
          {
            protected: true,
            identifier: 'platform_analytics_viewer',
            position: 6,
            resource_type: 'BetterTogether::Platform',
            name: 'Platform Analytics Viewer',
            description: 'Has read-only access to platform analytics and metrics, can generate and download ' \
                         'reports without access to other platform management functions.'
          }
        ]
      end

      def platform_resource_permission_attrs # rubocop:todo Metrics/MethodLength
        [
          {
            action: 'create', target: 'platform', resource_type: 'BetterTogether::Platform',
            identifier: 'create_platform', protected: true, position: 0
          },
          {
            action: 'read', target: 'platform', resource_type: 'BetterTogether::Platform', identifier: 'read_platform',
            protected: true, position: 1
          },
          {
            action: 'update', target: 'platform', resource_type: 'BetterTogether::Platform',
            identifier: 'update_platform', protected: true, position: 2
          },
          {
            action: 'delete', target: 'platform', resource_type: 'BetterTogether::Platform',
            identifier: 'delete_platform', protected: true, position: 3
          },
          {
            action: 'list', target: 'platform', resource_type: 'BetterTogether::Platform', identifier: 'list_platform',
            protected: true, position: 4
          },
          {
            action: 'manage', target: 'platform', resource_type: 'BetterTogether::Platform',
            identifier: 'manage_platform', protected: true, position: 6
          },
          {
            action: 'manage', target: 'platform_api', resource_type: 'BetterTogether::Platform',
            identifier: 'manage_platform_api', protected: true, position: 7
          },
          {
            action: 'manage', target: 'platform_data_privacy', resource_type: 'BetterTogether::Platform',
            identifier: 'manage_platform_data_privacy', protected: true, position: 8
          },
          {
            action: 'manage', target: 'platform_database', resource_type: 'BetterTogether::Platform',
            identifier: 'manage_platform_database', protected: true, position: 9
          },
          {
            action: 'manage', target: 'platform_deployment', resource_type: 'BetterTogether::Platform',
            identifier: 'manage_platform_deployment', protected: true, position: 10
          },
          {
            action: 'manage', target: 'platform_roles', resource_type: 'BetterTogether::Platform',
            identifier: 'manage_platform_roles', protected: true, position: 11
          },
          {
            action: 'manage', target: 'platform_security', resource_type: 'BetterTogether::Platform',
            identifier: 'manage_platform_security', protected: true, position: 12
          },
          {
            action: 'manage', target: 'platform_settings', resource_type: 'BetterTogether::Platform',
            identifier: 'manage_platform_settings', protected: true, position: 13
          },
          {
            action: 'manage', target: 'platform_users', resource_type: 'BetterTogether::Platform',
            identifier: 'manage_platform_users', protected: true, position: 14
          },
          {
            action: 'view', target: 'metrics_dashboard', resource_type: 'BetterTogether::Platform',
            identifier: 'view_metrics_dashboard', protected: true, position: 15
          },
          {
            action: 'create', target: 'metrics_reports', resource_type: 'BetterTogether::Platform',
            identifier: 'create_metrics_reports', protected: true, position: 16
          },
          {
            action: 'download', target: 'metrics_reports', resource_type: 'BetterTogether::Platform',
            identifier: 'download_metrics_reports', protected: true, position: 17
          },
          {
            action: 'view', target: 'platform_logs', resource_type: 'BetterTogether::Platform',
            identifier: 'view_platform_logs', protected: true, position: 18
          }
        ]
      end

      def person_resource_permission_attrs # rubocop:todo Metrics/MethodLength
        [
          {
            action: 'create', target: 'person', resource_type: 'BetterTogether::Person',
            identifier: 'create_person', protected: true, position: 0
          },
          {
            action: 'read', target: 'person', resource_type: 'BetterTogether::Person', identifier: 'read_person',
            protected: true, position: 1
          },
          {
            action: 'update', target: 'person', resource_type: 'BetterTogether::Person',
            identifier: 'update_person', protected: true, position: 2
          },
          {
            action: 'delete', target: 'person', resource_type: 'BetterTogether::Person',
            identifier: 'delete_person', protected: true, position: 3
          },
          {
            action: 'list', target: 'person', resource_type: 'BetterTogether::Person', identifier: 'list_person',
            protected: true, position: 4
          }
        ]
      end
    end
  end
end
