# frozen_string_literal: true

module BetterTogether
  # Notifies safety reviewers that a new report needs review.
  class SafetyReportSubmittedNotifier < ApplicationNotifier
    deliver_by :action_cable, channel: 'BetterTogether::NotificationsChannel', message: :build_message,
                              queue: :notifications

    required_param :report

    validates :record, presence: true

    def report
      params[:report] || record
    end

    def locale
      recipient&.locale || I18n.locale || I18n.default_locale
    end

    def title
      default_title = report.harm_level == 'urgent' ? 'Urgent safety report requires review' : 'New safety report requires review'

      I18n.with_locale(locale) do
        I18n.t(
          'better_together.notifications.safety_report_submitted.title',
          default: default_title
        )
      end
    end

    def body
      I18n.with_locale(locale) do
        I18n.t(
          'better_together.notifications.safety_report_submitted.body',
          harm_level: report.harm_level.humanize.downcase,
          reportable_type: report.reportable_type.demodulize.titleize,
          default: 'A %<harm_level>s-priority report about %<reportable_type>s is waiting in the safety review queue'
        )
      end
    end

    def build_message(_notification)
      { title:, body:, url: review_path }
    end

    notification_methods do
      delegate :title, :body, :review_path, to: :event
    end

    private

    def review_path
      BetterTogether::Engine.routes.url_helpers.safety_cases_path(locale:)
    end
  end
end
