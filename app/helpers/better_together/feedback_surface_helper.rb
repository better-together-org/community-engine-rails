# frozen_string_literal: true

module BetterTogether
  # Helper methods for the shared feedback surface UI.
  # rubocop:disable Metrics/ModuleLength
  module FeedbackSurfaceHelper
    FEEDBACK_SURFACE_SCOPE_KEYS = {
      BetterTogether::Content::Block => 'section',
      BetterTogether::Page => 'page',
      BetterTogether::Person => 'profile',
      BetterTogether::Community => 'community',
      BetterTogether::Post => 'post',
      BetterTogether::Event => 'event'
    }.freeze

    def feedback_surface_visible_for?(record, action_items: nil)
      feedback_surface_items_for(record, action_items:).any?
    end

    def feedback_surface_items_for(record, action_items: nil)
      items = Array(action_items).compact
      items << default_report_feedback_item(record) if feedback_surface_policy(record).report?
      items.compact
    end

    def feedback_surface_policy(record)
      BetterTogether::FeedbackPolicy.new(current_user, record)
    end

    def feedback_route_for(record, action_kind:)
      BetterTogether::FeedbackRoutingResolver.call(record, action_kind:)
    end

    def feedback_route_audience_label(record, action_kind:)
      route = feedback_route_for(record, action_kind:)

      t(
        "better_together.feedback_routing.audience.#{route.route}",
        default: route.route.to_s.humanize
      )
    end

    def feedback_route_reviewer_label(record, action_kind:)
      route = feedback_route_for(record, action_kind:)

      t(
        "better_together.feedback_routing.reviewers.#{route.route}",
        default: feedback_route_audience_label(record, action_kind:)
      )
    end

    def feedback_route_delivery_note(record, action_kind:)
      route = feedback_route_for(record, action_kind:)

      t(
        "better_together.feedback_routing.delivery.#{action_kind}.#{route.route}",
        audience: feedback_route_audience_label(record, action_kind:),
        default: "Sent to #{feedback_route_audience_label(record, action_kind:)}."
      )
    end

    def feedback_route_visibility_note(record, action_kind:)
      route = feedback_route_for(record, action_kind:)

      t(
        "better_together.feedback_routing.visibility.#{route.visibility}",
        default: route.visibility.to_s.humanize
      )
    end

    def feedback_route_exclusion_note(record, action_kind:)
      route = feedback_route_for(record, action_kind:)

      t(
        "better_together.feedback_routing.exclusions.#{action_kind}.#{route.route}",
        default: ''
      ).presence
    end

    def feedback_surface_scope_label(record, surface_scope: nil)
      t(
        "better_together.feedback_surface.scope.#{feedback_surface_scope_key(record, surface_scope:)}.label",
        default: feedback_surface_heading(record, surface_scope:)
      )
    end

    def feedback_surface_heading(record, surface_scope: nil)
      t(
        "better_together.feedback_surface.scope.#{feedback_surface_scope_key(record, surface_scope:)}.heading",
        default: "#{feedback_surface_resource_name(record)} feedback"
      )
    end

    def feedback_surface_description(record, surface_scope: nil)
      t(
        "better_together.feedback_surface.scope.#{feedback_surface_scope_key(record, surface_scope:)}.description",
        default: t(
          'better_together.feedback_surface.description',
          default: 'Use this area to raise safety concerns now and to host editor-reviewed feedback pathways later.'
        )
      )
    end

    def feedback_surface_aria_label(record, surface_scope: nil)
      t(
        'better_together.feedback_surface.aria_label',
        resource: feedback_surface_resource_name(record),
        surface: feedback_surface_scope_label(record, surface_scope:),
        default: '%<surface>s for %<resource>s'
      )
    end

    def feedback_surface_actions_label(record, surface_scope: nil)
      t(
        'better_together.feedback_surface.actions_label',
        resource: feedback_surface_resource_name(record),
        surface: feedback_surface_scope_label(record, surface_scope:),
        default: '%<surface>s actions for %<resource>s'
      )
    end

    def feedback_surface_action_link_classes(presentation, _item)
      base_classes = %w[bt-feedback-surface__action-link]
      base_classes << if presentation.to_sym == :compact
                        'btn btn-outline-danger btn-sm'
                      else
                        'btn btn-outline-danger'
                      end
      base_classes.join(' ')
    end

    def feedback_surface_resource_name(record)
      return record.title if record.respond_to?(:title) && record.title.present?
      return record.name if record.respond_to?(:name) && record.name.present?

      record.class.model_name.human
    end

    private

    def default_report_feedback_item(record)
      {
        id: 'report',
        href: feedback_surface_report_path(record),
        icon: 'fa-flag',
        label: feedback_surface_report_label,
        description: feedback_surface_report_description,
        policy_note: feedback_surface_report_policy_note(record)
      }
    end

    def feedback_surface_report_path(record)
      new_report_path(
        locale: I18n.locale,
        reportable_type: record.class.base_class.name,
        reportable_id: record.id
      )
    end

    def feedback_surface_report_label
      t('better_together.feedback_surface.report.label', default: 'Report safety issue')
    end

    def feedback_surface_report_description
      t(
        'better_together.feedback_surface.report.description',
        default: 'Privately flag this content for moderator review.'
      )
    end

    def feedback_surface_report_policy_note(record)
      feedback_route_delivery_note(record, action_kind: :report_safety_issue)
    end

    def feedback_surface_scope_key(record, surface_scope: nil)
      return surface_scope.to_s if surface_scope.present?

      FEEDBACK_SURFACE_SCOPE_KEYS.each do |klass, scope_key|
        return scope_key if record.is_a?(klass)
      end

      'content'
    end
  end
  # rubocop:enable Metrics/ModuleLength
end
