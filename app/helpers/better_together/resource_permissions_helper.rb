# frozen_string_literal: true

module BetterTogether
  # Helpers for resource permission views
  module ResourcePermissionsHelper
    RESOURCE_TYPE_STYLES = {
      'BetterTogether::Community' => { icon: 'fas fa-users', accent: 'bt-tab-accent--primary' },
      'BetterTogether::Platform' => { icon: 'fas fa-building', accent: 'bt-tab-accent--neutral' },
      'BetterTogether::Person' => { icon: 'fas fa-user', accent: 'bt-tab-accent--success' }
    }.freeze

    ACTION_STYLES = {
      'create' => { icon: 'fas fa-plus-circle', accent: 'bt-tab-accent--success' },
      'read' => { icon: 'fas fa-book', accent: 'bt-tab-accent--primary' },
      'update' => { icon: 'fas fa-edit', accent: 'bt-tab-accent--warning' },
      'delete' => { icon: 'fas fa-trash', accent: 'bt-tab-accent--danger' },
      'list' => { icon: 'fas fa-list', accent: 'bt-tab-accent--neutral' },
      'manage' => { icon: 'fas fa-shield-alt', accent: 'bt-tab-accent--primary' },
      'view' => { icon: 'fas fa-eye', accent: 'bt-tab-accent--primary' },
      'download' => { icon: 'fas fa-download', accent: 'bt-tab-accent--neutral' }
    }.freeze

    def resource_permission_resource_type_label(resource_type)
      resource_klass = BetterTogether::SafeClassResolver.resolve(
        resource_type,
        allowed: BetterTogether::Resourceful::RESOURCE_CLASSES
      )

      return resource_type unless resource_klass

      # Handle modules/namespaces that don't have model_name
      if resource_klass.respond_to?(:model_name)
        resource_klass.model_name.human
      else
        # For modules like BetterTogether::Metrics, use I18n or humanize the name
        I18n.t("activerecord.models.#{resource_type.underscore}", default: resource_type.demodulize.humanize)
      end
    end

    def resource_permission_action_label(action)
      I18n.t("better_together.resource_permissions.actions.#{action}", default: action.to_s.humanize)
    end

    def resource_permission_resource_type_style(resource_type)
      RESOURCE_TYPE_STYLES.fetch(resource_type, default_tab_style)
    end

    def resource_permission_action_style(action)
      ACTION_STYLES.fetch(action.to_s, default_tab_style)
    end

    def resource_permission_all_style
      { icon: 'fas fa-layer-group', accent: 'bt-tab-accent--neutral' }
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

    def default_tab_style
      { icon: 'fas fa-circle', accent: 'bt-tab-accent--neutral' }
    end
  end
end
