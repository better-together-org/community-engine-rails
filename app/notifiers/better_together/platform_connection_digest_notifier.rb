# frozen_string_literal: true

module BetterTogether
  # Collapses bursts of pending federation requests into one steward digest.
  class PlatformConnectionDigestNotifier < ApplicationNotifier
    deliver_by :action_cable, channel: 'BetterTogether::NotificationsChannel', message: :build_message,
                              queue: :notifications

    required_param :platform, :platform_connection_ids, :connection_count, :review_url

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
          'better_together.notifications.platform_connection_digest.title',
          count: connection_count,
          default: '%<count>s federation connections need review'
        )
      end
    end

    def body
      I18n.with_locale(locale) do
        I18n.t(
          'better_together.notifications.platform_connection_digest.body',
          count: connection_count,
          default: '%<count>s pending platform connections were added to the federation review queue'
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
      BetterTogether::Engine.routes.url_helpers.platform_connections_path(locale:)
    end

    def connection_count
      params[:connection_count].to_i
    end
  end
end
