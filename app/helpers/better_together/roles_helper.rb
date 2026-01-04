# frozen_string_literal: true

module BetterTogether
  # Helpers for role views
  module RolesHelper
    RESOURCE_TYPE_STYLES = {
      'BetterTogether::Community' => { icon: 'fas fa-users', accent: 'bt-tab-accent--primary' },
      'BetterTogether::Platform' => { icon: 'fas fa-building', accent: 'bt-tab-accent--neutral' },
      'BetterTogether::Person' => { icon: 'fas fa-user', accent: 'bt-tab-accent--success' }
    }.freeze

    def role_resource_type_label(resource_type)
      resource_klass = BetterTogether::SafeClassResolver.resolve(
        resource_type,
        allowed: BetterTogether::Resourceful::RESOURCE_CLASSES
      )

      return resource_type unless resource_klass

      # Handle modules (like BetterTogether::Metrics) that don't have model_name
      if resource_klass.is_a?(Module) && !resource_klass.respond_to?(:model_name)
        resource_klass.name.demodulize.titleize
      else
        resource_klass.model_name.human
      end
    end

    def role_resource_type_style(resource_type)
      RESOURCE_TYPE_STYLES.fetch(resource_type, default_role_tab_style)
    end

    def permission_display_name(permission)
      permission.identifier.to_s.tr('_', ' ').humanize
    end

    def role_permission_summary(role, limit: 3)
      permissions = role.resource_permissions.order(:resource_type, :position, :identifier)
      labels = permissions.first(limit).map { |permission| permission_display_name(permission) }
      remaining = permissions.size - labels.size

      { labels: labels, remaining: remaining, total: permissions.size }
    end

    def default_role_tab_style
      { icon: 'fas fa-circle', accent: 'bt-tab-accent--neutral' }
    end
  end
end
