# frozen_string_literal: true

module BetterTogether
  # Sends emails for PersonPlatformIntegration events
  class PersonPlatformIntegrationMailer < ApplicationMailer
    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def integration_created
      @person = params[:recipient]
      @integration = params[:person_platform_integration]
      platform = params[:platform]

      self.locale = @person.locale
      self.time_zone = @person.time_zone

      raw_url = platform&.url || BetterTogether.base_url
      @integration_url = better_together.settings_url(
        locale: @person.locale,
        anchor: 'integrations',
        **resolve_url_options(raw_url.to_s)
      )

      mail(
        to: @person.user.email,
        subject: t('better_together.person_platform_integration_mailer.integration_created.subject',
                   provider: @integration.provider.titleize)
      )
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
  end
end
