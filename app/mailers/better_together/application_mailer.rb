# frozen_string_literal: true

module BetterTogether
  # Base mailer for the engine
  class ApplicationMailer < ActionMailer::Base
    default from: ENV.fetch(
      'DEFAULT_FROM_EMAIL',
      'Better Together Community <community@bettertogethersolutions.com>'
    )

    helper BetterTogether::ApplicationHelper
    helper BetterTogether::ContactDetailsHelper
    helper BetterTogether::NavigationItemsHelper

    layout 'better_together/mailer'

    around_action :set_locale_and_time_zone

    attr_accessor :time_zone, :locale

    # Resolve the URL host for this mail delivery.
    # Resolution order:
    #   1. Explicit @platform ivar set by the child mailer (e.g. PlatformInvitationMailer)
    #   2. Current.platform set by Rack middleware (web/API requests)
    #   3. Global BetterTogether.base_url env fallback (background jobs with no request context)
    def default_url_options
      host = @platform&.url || ::Current.platform&.url || BetterTogether.base_url
      options = super.merge(locale:, host:)
      ActiveStorage::Current.url_options = options
      options
    end

    private

    # rubocop:todo Metrics/PerceivedComplexity
    # rubocop:todo Metrics/AbcSize
    def set_locale_and_time_zone(&) # rubocop:todo Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/PerceivedComplexity
      # Use Current.platform (set by middleware for web/API requests) with
      # fallback to host platform for background job mailer sends.
      platform = ::Current.platform ||
                 BetterTogether::Platform.find_by(host: true)

      self.time_zone ||= time_zone || platform&.time_zone || Rails.application.config.time_zone
      self.locale ||= locale || I18n.locale || platform&.locale || I18n.default_locale

      # Set time zone and locale either from platform or passed in by child mailers
      Time.use_zone(time_zone) do
        I18n.with_locale(locale, &)
      end
    end
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/PerceivedComplexity
  end
end
