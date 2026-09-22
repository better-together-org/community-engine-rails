# frozen_string_literal: true

module BetterTogether
  # Handles operational reviewer notifications for newly submitted safety reports.
  class SafetyReportNotificationService # rubocop:disable Metrics/ClassLength
    REVIEWER_PERMISSION = 'manage_platform_safety'
    DIGEST_WINDOW = 15.minutes
    DIGEST_THRESHOLD = 3
    DIGEST_NOTIFICATION_COOLDOWN = 30.minutes

    def initialize(report)
      @report = report
    end

    def notify_submission
      reviewer_recipients.each do |reviewer|
        recent_reports = digest_reports_for(reviewer)

        if recent_reports.size >= DIGEST_THRESHOLD
          deliver_digest_notification(reviewer, recent_reports)
        else
          deliver_individual_notification(reviewer)
        end
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
        .select { |person| person.user&.permitted_to?(REVIEWER_PERMISSION) }
        .reject { |person| person.id == report.reporter_id }
    end

    def host_platform
      @host_platform ||= BetterTogether::Platform.find_by(host: true)
    end

    def digest_reports_for(_reviewer)
      BetterTogether::Report
        .joins(:safety_case)
        .merge(BetterTogether::Safety::Case.open_cases)
        .where(created_at: DIGEST_WINDOW.ago..)
        .order(created_at: :desc)
        .to_a
    end

    def deliver_individual_notification(reviewer)
      return if submission_notification_exists?(reviewer)

      BetterTogether::SafetyReportSubmittedNotifier.with(
        record: report,
        report:,
        report_id: report.id,
        platform_id: host_platform&.id
      ).deliver_later(reviewer)
    end

    def deliver_digest_notification(reviewer, recent_reports)
      return if recent_reports.empty?
      return if digest_notification_recently_sent?(reviewer)

      remove_submission_notifications(reviewer)
      remove_digest_notifications(reviewer)

      BetterTogether::SafetyReportDigestNotifier.with(digest_notifier_params(recent_reports)).deliver_later(reviewer)
    end

    def submission_notification_exists?(reviewer)
      unread_notifications_for(reviewer).any? do |notification|
        notification.event.type == 'BetterTogether::SafetyReportSubmittedNotifier' &&
          notification_matches_report?(notification, report)
      end
    end

    def digest_notification_recently_sent?(reviewer)
      last_digest_notification = Noticed::Notification
                                 .includes(:event)
                                 .where(recipient: reviewer)
                                 .order(created_at: :desc)
                                 .detect do |notification|
        notification.event.type == 'BetterTogether::SafetyReportDigestNotifier' &&
          notification_matches_platform?(notification, host_platform)
      end

      last_digest_notification.present? &&
        last_digest_notification.created_at > DIGEST_NOTIFICATION_COOLDOWN.ago
    end

    def remove_submission_notifications(reviewer)
      notification_ids = unread_notifications_for(reviewer).filter_map do |notification|
        notification.id if notification.event.type == 'BetterTogether::SafetyReportSubmittedNotifier' &&
                           notification_matches_platform?(notification, host_platform)
      end

      Noticed::Notification.where(id: notification_ids).destroy_all if notification_ids.any?
    end

    def remove_digest_notifications(reviewer)
      notification_ids = unread_notifications_for(reviewer).filter_map do |notification|
        notification.id if notification.event.type == 'BetterTogether::SafetyReportDigestNotifier' &&
                           notification_matches_platform?(notification, host_platform)
      end

      Noticed::Notification.where(id: notification_ids).destroy_all if notification_ids.any?
    end

    def unread_notifications_for(reviewer)
      Noticed::Notification
        .includes(:event)
        .where(recipient: reviewer, read_at: nil)
    end

    def notification_matches_report?(notification, submitted_report)
      params = notification.event.params.with_indifferent_access
      params[:report]&.id == submitted_report.id || params[:report_id] == submitted_report.id
    end

    def notification_matches_platform?(notification, platform)
      params = notification.event.params.with_indifferent_access
      params[:platform]&.id == platform&.id || params[:platform_id] == platform&.id
    end

    def review_url
      return unless host_platform&.persisted?

      BetterTogether::Engine.routes.url_helpers.safety_cases_url(locale: I18n.locale)
    end

    def digest_notifier_params(recent_reports)
      {
        record: host_platform,
        platform: host_platform,
        platform_id: host_platform&.id,
        report_ids: recent_reports.map(&:id),
        report_count: recent_reports.size,
        urgent_count: recent_reports.count { |item| item.harm_level == 'urgent' },
        retaliation_risk_count: recent_reports.count(&:retaliation_risk?),
        review_url:
      }
    end

    attr_reader :report
  end
end
