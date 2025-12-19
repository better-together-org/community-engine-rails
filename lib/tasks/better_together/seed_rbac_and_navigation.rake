# frozen_string_literal: true

namespace :better_together do
  namespace :seed do
    desc 'Seed new roles, permissions, assignments, and navigation items'
    task rbac_and_navigation: :environment do
      I18n.with_locale(:en) do
        seed_platform_permissions
        seed_platform_analytics_viewer_role
        assign_metrics_permissions_to_platform_roles
        seed_platform_host_analytics_nav_item
        migrate_legacy_analytics_assignments
        remove_legacy_platform_analytics_permission
      end
    end

    def seed_platform_permissions
      platform_permissions.each do |attrs|
        permission = BetterTogether::ResourcePermission.find_or_initialize_by(identifier: attrs[:identifier])
        permission.assign_attributes(attrs.except(:position))
        permission.save! if permission.changed?
      end
    end

    def seed_platform_analytics_viewer_role
      role = BetterTogether::Role.find_or_initialize_by(identifier: 'platform_analytics_viewer')
      role.assign_attributes(
        protected: true,
        resource_type: 'BetterTogether::Platform',
        name: 'Platform Analytics Viewer',
        description: 'Has read-only access to platform analytics and metrics, can generate and download ' \
                     'reports without access to other platform management functions.'
      )
      role.save! if role.changed?
    end

    def migrate_legacy_analytics_assignments
      new_role = BetterTogether::Role.find_by(identifier: 'platform_analytics_viewer')
      return unless new_role

      legacy_role_ids = legacy_analytics_role_ids
      return if legacy_role_ids.empty?

      migrate_platform_invitations(legacy_role_ids, new_role)
      migrate_platform_memberships(legacy_role_ids, new_role)
    end

    def remove_legacy_platform_analytics_permission
      legacy_permission = BetterTogether::ResourcePermission.find_by(identifier: 'view_platform_analytics')
      return unless legacy_permission

      BetterTogether::RoleResourcePermission.where(resource_permission_id: legacy_permission.id).delete_all
      legacy_permission.update_columns(protected: false) if legacy_permission.respond_to?(:protected)
      legacy_permission.delete
    end

    def assign_metrics_permissions_to_platform_roles
      role_identifiers = %w[
        platform_manager
        platform_infrastructure_architect
        platform_tech_support
        platform_developer
        platform_quality_assurance_lead
        platform_accessibility_officer
        platform_analytics_viewer
      ]

      permission_identifiers = %w[
        view_metrics_dashboard
        create_metrics_reports
        download_metrics_reports
      ]

      role_identifiers.each do |identifier|
        role = BetterTogether::Role.find_by(identifier: identifier)
        next unless role

        role.assign_resource_permissions(permission_identifiers)
      end
    end

    def seed_platform_host_analytics_nav_item
      navigation_area = find_or_create_platform_host_nav_area
      host_nav = find_or_create_platform_host_nav_item(navigation_area)

      analytics_item = BetterTogether::NavigationItem.find_or_initialize_by(
        identifier: 'analytics',
        navigation_area: navigation_area,
        parent: host_nav
      )

      if analytics_item.new_record? || analytics_item.position.blank?
        shift_host_nav_positions_for_analytics(host_nav)
        analytics_item.assign_attributes(analytics_nav_attributes)
      else
        analytics_item.visibility_strategy = 'permission'
        analytics_item.permission_identifier = 'view_metrics_dashboard'
        analytics_item.route_name ||= 'metrics_reports_url'
        analytics_item.icon ||= 'chart-line'
        analytics_item.privacy ||= 'private'
        analytics_item.position ||= 1
      end

      analytics_item.save! if analytics_item.changed?
    end

    def find_or_create_platform_host_nav_area
      navigation_area = BetterTogether::NavigationArea.find_or_initialize_by(identifier: 'platform-host')
      return navigation_area if navigation_area.persisted?

      navigation_area.assign_attributes(
        name: 'Platform Host',
        slug: 'platform-host',
        visible: true,
        protected: true
      )
      navigation_area.save!
      navigation_area
    end

    def find_or_create_platform_host_nav_item(navigation_area)
      host_nav = BetterTogether::NavigationItem.find_or_initialize_by(
        identifier: 'host-nav',
        navigation_area: navigation_area,
        parent_id: nil
      )
      return host_nav if host_nav.persisted?

      host_nav.assign_attributes(
        title: 'Host',
        slug: 'host-nav',
        position: 0,
        visible: true,
        protected: true,
        item_type: 'dropdown',
        url: '#'
      )
      host_nav.save!
      host_nav
    end

    def analytics_nav_attributes
      {
        title: 'Analytics',
        slug: 'analytics',
        position: 1,
        item_type: 'link',
        route_name: 'metrics_reports_url',
        icon: 'chart-line',
        visible: true,
        protected: true,
        privacy: 'private',
        visibility_strategy: 'permission',
        permission_identifier: 'view_metrics_dashboard'
      }
    end

    def shift_host_nav_positions_for_analytics(host_nav)
      scope = BetterTogether::NavigationItem
              .where(parent_id: host_nav.id)
              .where('position >= ?', 1)
      return if scope.none?

      offset = (scope.maximum(:position) || 0) + 2
      scope.update_all("position = position + #{offset}")
      scope.update_all("position = position - #{offset - 1}")
    end

    def legacy_analytics_role_ids
      BetterTogether::Role
        .where(resource_type: 'BetterTogether::Platform')
        .where('identifier ILIKE ?', '%analytics%')
        .where.not(identifier: 'platform_analytics_viewer')
        .pluck(:id)
    end

    def migrate_platform_invitations(legacy_role_ids, new_role)
      BetterTogether::PlatformInvitation.where(platform_role_id: legacy_role_ids).find_each do |invitation|
        invitation.update!(platform_role_id: new_role.id)
      end
    end

    def migrate_platform_memberships(legacy_role_ids, new_role)
      BetterTogether::PersonPlatformMembership.where(role_id: legacy_role_ids).find_each do |membership|
        existing = BetterTogether::PersonPlatformMembership.find_by(
          member_id: membership.member_id,
          joinable_id: membership.joinable_id,
          role_id: new_role.id
        )

        if existing
          membership.destroy!
        else
          membership.update!(role_id: new_role.id)
        end
      end
    end

    def platform_permissions
      [
        {
          action: 'view',
          target: 'metrics_dashboard',
          resource_type: 'BetterTogether::Platform',
          identifier: 'view_metrics_dashboard',
          protected: true
        },
        {
          action: 'create',
          target: 'metrics_reports',
          resource_type: 'BetterTogether::Platform',
          identifier: 'create_metrics_reports',
          protected: true
        },
        {
          action: 'download',
          target: 'metrics_reports',
          resource_type: 'BetterTogether::Platform',
          identifier: 'download_metrics_reports',
          protected: true
        }
      ]
    end
  end
end
