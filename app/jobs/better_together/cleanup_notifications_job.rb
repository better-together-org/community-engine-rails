# frozen_string_literal: true

module BetterTogether
  # Background job to clean up notifications when a record is destroyed
  class CleanupNotificationsJob < ApplicationJob
    queue_as :notifications

    # rubocop:todo Lint/CopDirectiveSyntax
    def perform(record_type:, record_id:) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength, Metrics/MethodLength
      # rubocop:enable Lint/CopDirectiveSyntax
      Rails.logger.info("Cleaning up notifications for #{record_type}##{record_id}")

      # Find all events where the destroyed record was the record
      # Exclude removal notifications as they are meant to persist after record destruction
      events = Noticed::Event.where(
        record_type: record_type,
        record_id: record_id
      ).where.not(type: 'BetterTogether::MembershipRemovedNotifier')

      return if events.empty?

      notifications_count = 0
      events_count = 0
      events.find_each do |event|
        # Count notifications before destroying them
        notifications_count += event.notifications.count

        # Destroy associated notifications
        event.notifications.destroy_all

        # Destroy the event itself
        event.destroy
        events_count += 1
      end

      Rails.logger.info("Cleaned up #{notifications_count} notifications and #{events_count} events for #{record_type}##{record_id}")
    rescue StandardError => e
      Rails.logger.error("Failed to clean up notifications for #{record_type}##{record_id}: #{e.message}")
      raise e
    end
  end
end
