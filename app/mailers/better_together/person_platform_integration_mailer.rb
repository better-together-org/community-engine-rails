# frozen_string_literal: true

module BetterTogether
  # Sends emails for PersonPlatformIntegration events
  class PersonPlatformIntegrationMailer < ApplicationMailer
    def integration_created
      @person = params[:recipient]
      @integration = params[:person_platform_integration]
      @integration_url = better_together.settings_url(
        locale: I18n.locale,
        host: BetterTogether.base_url,
        anchor: 'integrations'
      )

      mail(
        to: @person.user.email,
        subject: t('better_together.person_platform_integration_mailer.integration_created.subject',
                   provider: @integration.provider.titleize)
      )
    end
  end
end
