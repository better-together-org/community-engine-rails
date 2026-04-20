# frozen_string_literal: true

module BetterTogether
  # Notifies network stewards when a new platform connection needs review.
  class PlatformConnectionSubmittedNotifier < ApplicationNotifier
    deliver_by :action_cable, channel: 'BetterTogether::NotificationsChannel', message: :build_message,
                              queue: :notifications

    required_param :platform_connection

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
          'better_together.notifications.platform_connection_submitted.title',
          default: 'New federation connection requires review'
        )
      end
    end

    def body
      I18n.with_locale(locale) do
        I18n.t(
          'better_together.notifications.platform_connection_submitted.body',
          source_name: platform_connection.source_platform.name,
          target_name: platform_connection.target_platform.name,
          default: '%<source_name>s requested a federation connection with %<target_name>s'
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
  end
end
