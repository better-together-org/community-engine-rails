# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Base controller for Joatu resources, adds notification mark-as-read helpers
    class JoatuController < BetterTogether::FriendlyResourceController
      # Normalize translated params so base keys are populated for current locale.
      # This helps presence validations (esp. for ActionText) during create/update
      # when forms submit locale-suffixed fields like `description_en`.
      def resource_params # rubocop:todo Metrics/CyclomaticComplexity, Metrics/MethodLength
        rp = super
        return rp unless rp.is_a?(ActionController::Parameters) || rp.is_a?(Hash)

        locale = I18n.locale.to_s
        # rubocop:todo Layout/LineLength
        %w[name description].each do |attr|
          # rubocop:enable Layout/LineLength
          localized_key_sym = :"#{attr}_#{locale}"
          localized_key_str = "#{attr}_#{locale}"
          next if rp.key?(attr) && rp[attr].present?

          val = rp[localized_key_sym] || rp[localized_key_str]
          rp[attr] = val if val.present?
        end

        rp
      end

      protected

      # Mark Noticed notifications as read for a specific record-based event
      def mark_notifications_read_for_record(record)
        return unless helpers.current_person && record.respond_to?(:id)

        helpers.current_person.notifications.unread
               .includes(:event)
               .references(:event)
               .where(event: { record_id: record.id })
               .update_all(read_at: Time.current)
      end

      # Mark Joatu match notifications as read when viewing an offer or request
      def mark_match_notifications_read_for(record) # rubocop:todo Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
        return unless helpers.current_person && record.respond_to?(:id)

        helpers.current_person.notifications.unread.includes(:event).find_each do |notification|
          event = notification.event
          next unless event.is_a?(BetterTogether::Joatu::MatchNotifier)

          begin
            ids = []
            ids << event.offer&.id if event.respond_to?(:offer)
            ids << event.request&.id if event.respond_to?(:request)
            notification.update(read_at: Time.current) if ids.compact.include?(record.id)
          rescue StandardError
            next
          end
        end
      end
    end
  end
end
