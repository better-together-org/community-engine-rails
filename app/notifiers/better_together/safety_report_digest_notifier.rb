# frozen_string_literal: true

module BetterTogether
  # Collapses bursts of new safety reports into one reviewer digest.
  class SafetyReportDigestNotifier < ApplicationNotifier
    deliver_by :action_cable, channel: 'BetterTogether::NotificationsChannel', message: :build_message,
                              queue: :notifications

    required_param :platform, :report_ids, :report_count, :urgent_count, :retaliation_risk_count, :review_url

    validates :record, presence: true

    def platform
      params[:platform] || record
    end

    def locale
      recipient&.locale || I18n.locale || I18n.default_locale
    end

    def title
      I18n.with_locale(locale) do
        I18n.t(
          'better_together.notifications.safety_report_digest.title',
          count: report_count,
          default: '%<count>s safety reports need review'
        )
      end
    end

    def body
      I18n.with_locale(locale) do
        I18n.t(
          'better_together.notifications.safety_report_digest.body',
          urgent_count:,
          retaliation_risk_count:,
          default: '%<urgent_count>s urgent reports and %<retaliation_risk_count>s retaliation-risk reports were added to the review queue'
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

    def report_count
      params[:report_count].to_i
    end

    def urgent_count
      params[:urgent_count].to_i
    end

    def retaliation_risk_count
      params[:retaliation_risk_count].to_i
    end
  end
end
