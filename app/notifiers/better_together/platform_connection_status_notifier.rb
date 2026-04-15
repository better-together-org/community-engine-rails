# frozen_string_literal: true

module BetterTogether
  # Notifies network stewards when a platform connection changes status.
  class PlatformConnectionStatusNotifier < ApplicationNotifier
    deliver_by :action_cable, channel: 'BetterTogether::NotificationsChannel', message: :build_message,
                              queue: :notifications

    required_param :platform_connection, :previous_status, :current_status

    validates :record, presence: true

    def platform_connection
      params[:platform_connection] || record
    end

    def locale
      recipient&.locale || I18n.locale || I18n.default_locale
    end

    def title
      I18n.with_locale(locale) do
        I18n.t(
          'better_together.notifications.platform_connection_status.title',
          current_status: current_status_label,
          default: 'Federation connection %<current_status>s'
        )
      end
    end

    def body
      I18n.with_locale(locale) do
        I18n.t(
          'better_together.notifications.platform_connection_status.body',
          source_name: platform_connection.source_platform.name,
          target_name: platform_connection.target_platform.name,
          previous_status: previous_status_label,
          current_status: current_status_label,
          default: '%<source_name>s and %<target_name>s moved from %<previous_status>s to %<current_status>s'
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
      BetterTogether::Engine.routes.url_helpers.platform_connection_path(platform_connection, locale:)
    end

    def current_status_label
      params[:current_status].to_s.tr('_', ' ')
    end

    def previous_status_label
      params[:previous_status].to_s.tr('_', ' ')
    end
  end
end
