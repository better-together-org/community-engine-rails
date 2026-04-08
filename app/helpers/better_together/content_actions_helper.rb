# frozen_string_literal: true

module BetterTogether
  # Helper methods for the shared content actions menu.
  module ContentActionsHelper
    def content_actions_visible_for?(record, action_items: nil)
      content_actions_items_for(record, action_items:).any?
    end

    def content_actions_items_for(record, action_items: nil)
      items = Array(action_items).compact
      items << default_report_action_item(record) if can_report_record?(record)
      items.compact
    end

    def can_report_record?(record)
      return false unless current_user.present? && current_person.present? && record.present?
      return false unless reportable_record?(record)
      return false if owned_by_current_person?(record)

      true
    end

    def content_actions_trigger_label(record)
      t(
        'better_together.content_actions.trigger_label',
        resource: content_actions_resource_name(record),
        default: 'More actions for %<resource>s'
      )
    end

    def content_actions_menu_label(record)
      t(
        'better_together.content_actions.menu_label',
        resource: content_actions_resource_name(record),
        default: 'Actions for %<resource>s'
      )
    end

    def content_actions_resource_name(record)
      return record.title if record.respond_to?(:title) && record.title.present?
      return record.name if record.respond_to?(:name) && record.name.present?

      record.class.model_name.human
    end

    private

    def reportable_record?(record)
      BetterTogether::Report::ALLOWED_REPORTABLES.include?(record.class.base_class.name)
    end

    def owned_by_current_person?(record)
      owner_candidates(record).include?(current_person)
    end

    # rubocop:disable Metrics/AbcSize
    def owner_candidates(record)
      [].tap do |owners|
        owners << record if record.is_a?(BetterTogether::Person)
        owners << record.creator if record.respond_to?(:creator) && record.creator.present?
        owners << record.author if record.respond_to?(:author) && record.author.present?
        owners.concat(Array(record.authors)) if record.respond_to?(:authors)
      end.compact.uniq
    end
    # rubocop:enable Metrics/AbcSize

    # rubocop:disable Metrics/MethodLength
    def default_report_action_item(record)
      {
        id: 'report',
        href: new_report_path(
          locale: I18n.locale,
          reportable_type: record.class.base_class.name,
          reportable_id: record.id
        ),
        icon: 'fa-flag',
        label: t(
          'better_together.content_actions.report.label',
          default: 'Report safety issue'
        ),
        description: t(
          'better_together.content_actions.report.description',
          default: 'Flag this content for moderator review.'
        )
      }
    end
    # rubocop:enable Metrics/MethodLength
  end
end
