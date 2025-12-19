# frozen_string_literal: true

module BetterTogether
  # Helpers for role views
  module RolesHelper
    def role_resource_type_label(resource_type)
      resource_klass = BetterTogether::SafeClassResolver.resolve(
        resource_type,
        allowed: BetterTogether::Resourceful::RESOURCE_CLASSES
      )

      resource_klass ? resource_klass.model_name.human : resource_type
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
  end
end
