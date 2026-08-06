# frozen_string_literal: true

module BetterTogether
  # Notifies a content creator when their item's per-item federation_visibility
  # override changes (platform_default/federate/no_federate), confirming what
  # took effect. Mirrors PlatformConnectionStatusNotifier's status-change pattern,
  # applied to individual federatable content items instead of connections.
  class FederationVisibilityStatusNotifier < ApplicationNotifier
    deliver_by :action_cable, channel: 'BetterTogether::NotificationsChannel', message: :build_message,
                              queue: :notifications

    required_param :federatable, :previous_visibility, :current_visibility

    validates :record, presence: true

    def federatable
      params[:federatable] || record
    end

    def title
      I18n.with_locale(locale) do
        I18n.t(
          'better_together.notifications.federation_visibility_status.title',
          current_visibility: current_visibility_label,
          default: 'Federation setting updated: %<current_visibility>s'
        )
      end
    end

    def body
      I18n.with_locale(locale) do
        I18n.t(
          'better_together.notifications.federation_visibility_status.body',
          title: federatable.to_s,
          current_visibility: current_visibility_label,
          default: '"%<title>s" is now set to %<current_visibility>s'
        )
      end
    end

    def build_message(notification)
      I18n.with_locale(locale_for_notification(notification)) do
        { title:, body:, url: }
      end
    end

    notification_methods do
      delegate :title, :body, :url, to: :event
    end

    def url
      ::BetterTogether::Engine.routes.url_helpers.polymorphic_path(federatable, locale:)
    rescue StandardError
      nil
    end

    def current_visibility_label
      params[:current_visibility].to_s.tr('_', ' ')
    end
  end
end
