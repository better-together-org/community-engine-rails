# frozen_string_literal: true

module BetterTogether
  # Saves the signed-in person's cookie consent decision. The banner and the settings form both
  # post here; the server records the decision on the person and rewrites the cookie so the two
  # never disagree. Only the two category booleans are accepted: the date and policy version are
  # set by the server.
  class CookieConsentsController < ApplicationController
    AFFIRMATIVE = %w[1 true on].freeze

    before_action :authenticate_user!
    after_action :verify_authorized

    def update
      authorize current_user.person, policy_class: CookieConsentPolicy

      version = helpers.consent_policy_version
      preference = ConsentPreference.new(current_user.person).record!(consent_params, policy_version: version)
      write_consent_cookie(preference.decision, version)
      respond_with_decision(preference, version)
    end

    private

    # A category that is missing or not clearly affirmative counts as declined.
    def consent_params
      permitted = params.fetch(:consent, {}).permit(*Consent::CATEGORIES)
      Consent::CATEGORIES.index_with { |category| AFFIRMATIVE.include?(permitted[category].to_s.downcase) }
    end

    def respond_with_decision(preference, version)
      respond_to do |format|
        format.json { render json: payload(preference, version) }
        format.html do
          redirect_to settings_path(locale: I18n.locale, anchor: 'cookie-consent'),
                      notice: t('better_together.consent.saved')
        end
      end
    end

    def payload(preference, version)
      preference.decision.merge('decided_at' => preference.decided_at&.iso8601, 'policy_version' => version)
    end
  end
end
