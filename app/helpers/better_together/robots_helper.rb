# frozen_string_literal: true

module BetterTogether
  # Presentation helpers for platform-managed robot configuration views.
  module RobotsHelper
    def robot_scope_badge_class(robot)
      robot.global_fallback? ? 'text-bg-secondary' : 'text-bg-primary'
    end

    def robot_scope_label(robot)
      key = robot.global_fallback? ? 'global_fallback' : 'platform_override'
      t("better_together.robots.scope_labels.#{key}")
    end

    def robot_provider_status_class(robot)
      BetterTogether.llm_provider_available?(robot:) ? 'text-success' : 'text-danger'
    end

    def robot_provider_status_text(robot)
      key = BetterTogether.llm_provider_available?(robot:) ? 'provider_ready' : 'provider_unavailable'
      t("better_together.robots.statuses.#{key}")
    end

    def translation_robot_status_text(robot, resolved_robot, translation_available)
      return t('better_together.robots.statuses.inactive_translation') unless robot.active?
      return t('better_together.robots.statuses.translation_not_selected') unless resolved_robot == robot

      key = translation_available ? 'translation_ui_enabled' : 'translation_ui_disabled'
      t("better_together.robots.statuses.#{key}")
    end
  end
end
