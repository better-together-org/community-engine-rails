# frozen_string_literal: true

module BetterTogether
  module Billing
    # Logs every change to a payment method setting as a billing event, so a changed payment
    # destination (the usual way payments get redirected) can always be traced.
    #
    # The event names the FIELDS that changed and who changed them, never the values: the
    # values are where buyers are told to send money. Needs `changed_by` (the person making
    # the change, not stored) and `settings`, and the including model must be Subjectable.
    module SettingAudit
      extend ActiveSupport::Concern

      included do
        after_save :record_audit_event
      end

      private

      def record_audit_event
        changes = changed_field_names
        return if changes.empty?

        platform.billing_events.create!(audit_event_attributes(changes))
      end

      def changed_field_names
        (saved_changes.keys - %w[updated_at lock_version created_at id settings]) + settings_changed_keys.map { |key| "settings.#{key}" }
      end

      def settings_changed_keys
        return [] unless saved_change_to_settings

        before, after = saved_change_to_settings.map { |value| value.to_h.stringify_keys }
        (before.keys | after.keys).reject { |key| before[key] == after[key] }
      end

      def audit_event_attributes(changes)
        event_id = SecureRandom.uuid
        type = "#{processor}.settings_changed"
        { processor:, event_id:, event_type: type, processing_status: 'processed', processed_at: Time.current,
          outcome_kind: 'settings_changed', subject: self,
          payload: { 'id' => event_id, 'type' => type, 'outcome_kind' => 'settings_changed', 'enabled' => enabled,
                     'changed' => changes, 'actor_id' => changed_by&.id } }
      end
    end
  end
end
