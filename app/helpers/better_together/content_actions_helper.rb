# frozen_string_literal: true

module BetterTogether
  # Helper methods for the shared feedback surface and compatibility wrappers.
  module ContentActionsHelper
    def content_actions_visible_for?(record, action_items: nil)
      feedback_surface_visible_for?(record, action_items:)
    end

    def content_actions_items_for(record, action_items: nil)
      feedback_surface_items_for(record, action_items:)
    end

    def can_report_record?(record)
      feedback_surface_policy(record).report?
    end

    def content_actions_trigger_label(record)
      t(
        'better_together.content_actions.trigger_label',
        resource: feedback_surface_resource_name(record),
        default: 'More actions for %<resource>s'
      )
    end

    def content_actions_menu_label(record)
      t(
        'better_together.content_actions.menu_label',
        resource: feedback_surface_resource_name(record),
        default: 'Actions for %<resource>s'
      )
    end

    def content_actions_resource_name(record)
      feedback_surface_resource_name(record)
    end
  end
end
