# frozen_string_literal: true

module BetterTogether
  # Handles steward notifications for pending and updated platform connections.
  class PlatformConnectionNotificationService # rubocop:disable Metrics/ClassLength
    REVIEWER_PERMISSIONS = %w[manage_network_connections approve_network_connections].freeze
    DIGEST_WINDOW = 15.minutes
    DIGEST_THRESHOLD = 3
    DIGEST_NOTIFICATION_COOLDOWN = 30.minutes
    STATUS_NOTIFICATION_VALUES = %w[active suspended blocked].freeze

    def initialize(platform_connection)
      @platform_connection = platform_connection
    end

    def notify_submission
      reviewer_recipients.each do |reviewer|
        recent_connections = digest_connections_for(reviewer)

        if recent_connections.size >= DIGEST_THRESHOLD
          deliver_digest_notification(reviewer, recent_connections)
        else
          deliver_individual_notification(reviewer)
        end
      end
    end

    def notify_status_change(previous_status:)
      return if previous_status == platform_connection.status
      return unless STATUS_NOTIFICATION_VALUES.include?(platform_connection.status)

      reviewer_recipients.each do |reviewer|
        next if status_notification_exists?(reviewer)

        BetterTogether::PlatformConnectionStatusNotifier.with(
          record: platform_connection,
          platform_connection:,
          platform_connection_id: platform_connection.id,
          previous_status:,
          current_status: platform_connection.status
        ).deliver_later(reviewer)
      end
    end

    private

    def reviewer_recipients
      return [] unless host_platform

      BetterTogether::PersonPlatformMembership
        .includes(:member)
        .active
        .where(joinable: host_platform)
        .map(&:member)
        .compact
        .uniq(&:id)
        .select { |person| network_steward?(person) }
    end

    def host_platform
      @host_platform ||= BetterTogether::Platform.find_by(host: true)
    end

    def digest_connections_for(_reviewer)
      BetterTogether::PlatformConnection
        .where(status: 'pending', created_at: DIGEST_WINDOW.ago..)
        .order(created_at: :desc)
        .to_a
    end

    def deliver_individual_notification(reviewer)
      return if submission_notification_exists?(reviewer)

      BetterTogether::PlatformConnectionSubmittedNotifier.with(
        record: platform_connection,
        platform_connection:,
        platform_connection_id: platform_connection.id
      ).deliver_later(reviewer)
    end

    def deliver_digest_notification(reviewer, recent_connections)
      return if recent_connections.empty?
      return if digest_notification_recently_sent?(reviewer)

      remove_submission_notifications(reviewer)
      remove_digest_notifications(reviewer)

      BetterTogether::PlatformConnectionDigestNotifier.with(
        record: host_platform,
        platform: host_platform,
        platform_id: host_platform&.id,
        platform_connection_ids: recent_connections.map(&:id),
        connection_count: recent_connections.size,
        review_url:
      ).deliver_later(reviewer)
    end

    def submission_notification_exists?(reviewer)
      unread_notifications_for(reviewer).any? do |notification|
        notification.event.type == 'BetterTogether::PlatformConnectionSubmittedNotifier' &&
          notification_matches_connection?(notification, platform_connection)
      end
    end

    def status_notification_exists?(reviewer)
      unread_notifications_for(reviewer).any? do |notification|
        notification.event.type == 'BetterTogether::PlatformConnectionStatusNotifier' &&
          notification_matches_connection?(notification, platform_connection) &&
          notification_matches_status?(notification, platform_connection.status)
      end
    end

    def digest_notification_recently_sent?(reviewer)
      last_digest_notification = Noticed::Notification
                                 .includes(:event)
                                 .where(recipient: reviewer)
                                 .order(created_at: :desc)
                                 .detect do |notification|
        notification.event.type == 'BetterTogether::PlatformConnectionDigestNotifier' &&
          notification_matches_platform?(notification, host_platform)
      end

      last_digest_notification.present? &&
        last_digest_notification.created_at > DIGEST_NOTIFICATION_COOLDOWN.ago
    end

    def remove_submission_notifications(reviewer)
      notification_ids = unread_notifications_for(reviewer).filter_map do |notification|
        notification.id if notification.event.type == 'BetterTogether::PlatformConnectionSubmittedNotifier'
      end

      Noticed::Notification.where(id: notification_ids).destroy_all if notification_ids.any?
    end

    def remove_digest_notifications(reviewer)
      notification_ids = unread_notifications_for(reviewer).filter_map do |notification|
        notification.id if notification.event.type == 'BetterTogether::PlatformConnectionDigestNotifier' &&
                           notification_matches_platform?(notification, host_platform)
      end

      Noticed::Notification.where(id: notification_ids).destroy_all if notification_ids.any?
    end

    def unread_notifications_for(reviewer)
      Noticed::Notification
        .includes(:event)
        .where(recipient: reviewer, read_at: nil)
    end

    def notification_matches_connection?(notification, connection)
      params = notification.event.params.with_indifferent_access
      params[:platform_connection]&.id == connection.id || params[:platform_connection_id] == connection.id
    end

    def notification_matches_platform?(notification, platform)
      params = notification.event.params.with_indifferent_access
      params[:platform]&.id == platform&.id || params[:platform_id] == platform&.id
    end

    def notification_matches_status?(notification, status)
      notification.event.params.with_indifferent_access[:current_status] == status
    end

    def review_url
      BetterTogether::Engine.routes.url_helpers.platform_connections_url(locale: I18n.locale)
    end

    def network_steward?(person)
      person.user&.permitted_to?('manage_network_connections') ||
        person.user&.permitted_to?('approve_network_connections')
    end

    attr_reader :platform_connection
  end
end
