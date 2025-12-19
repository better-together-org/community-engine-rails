# frozen_string_literal: true

module BetterTogether
  # Helpers for resource permission views
  module ResourcePermissionsHelper
    def resource_permission_resource_type_label(resource_type)
      resource_klass = BetterTogether::SafeClassResolver.resolve(
        resource_type,
        allowed: BetterTogether::Resourceful::RESOURCE_CLASSES
      )

      resource_klass ? resource_klass.model_name.human : resource_type
    end

    def role_display_name(role)
      role.name.presence || role.identifier
    end

    def resource_permission_role_summary(resource_permission, limit: 3)
      roles = resource_permission.roles.order(:resource_type, :position, :identifier)
      labels = roles.first(limit).map { |role| role_display_name(role) }
      remaining = roles.size - labels.size

      { labels: labels, remaining: remaining, total: roles.size }
    end
  end
end
