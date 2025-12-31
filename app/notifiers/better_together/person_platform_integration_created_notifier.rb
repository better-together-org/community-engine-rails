# frozen_string_literal: true

module BetterTogether
  # Notifies person when a new OAuth integration is created
  class PersonPlatformIntegrationCreatedNotifier < ApplicationNotifier
    deliver_by :action_cable, channel: 'BetterTogether::NotificationsChannel', message: :build_message,
                              queue: :notifications
    deliver_by :email, mailer: 'BetterTogether::PersonPlatformIntegrationMailer', method: :integration_created,
                       params: :email_params, queue: :mailers do |config|
      config.if = -> { recipient_has_email? }
    end

    required_param :person_platform_integration

    validates :record, presence: true

    def integration
      params[:person_platform_integration] || record
    end

    def person
      integration&.person
    end

    def locale
      person&.locale || I18n.locale || I18n.default_locale
    end

    def title
      I18n.with_locale(locale) do
        I18n.t('better_together.notifications.person_platform_integration_created.title',
               provider: provider_name,
               default: 'New %<provider>s integration connected')
      end
    end

    def body
      I18n.with_locale(locale) do
        I18n.t('better_together.notifications.person_platform_integration_created.body',
               provider: provider_name,
               created_at: formatted_created_at,
               default: 'A new %<provider>s account integration was connected on %<created_at>s')
      end
    end

    def build_message(_notification)
      { title:, body:, url: }
    end

    def email_params(_notification)
      { person_platform_integration: integration, recipient: person }
    end

    notification_methods do
      delegate :integration, :person, :title, :body, :url, to: :event

      def recipient_has_email?
        recipient.respond_to?(:user) && recipient.user&.email.present? &&
          (!recipient.respond_to?(:notification_preferences) ||
           recipient.notification_preferences.fetch('notify_by_email', true))
      end
    end

    def url
      return unless integration

      BetterTogether::Engine.routes.url_helpers.person_platform_integration_path(integration, locale:)
    end

    private

    def provider_name
      integration&.provider&.titleize || 'OAuth'
    end

    def formatted_created_at
      return unless integration&.created_at

      I18n.with_locale(locale) do
        I18n.l(integration.created_at, format: :long)
      end
    end
  end
end
