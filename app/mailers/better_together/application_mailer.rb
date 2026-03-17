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
      raw = @platform&.url || ::Current.platform&.url || BetterTogether.base_url
      options = super.merge(locale:, **resolve_url_options(raw.to_s))
      ActiveStorage::Current.url_options = options
      options
    end

    private

    # rubocop:todo Metrics/PerceivedComplexity
    # rubocop:todo Metrics/AbcSize
    def set_locale_and_time_zone(&) # rubocop:todo Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/PerceivedComplexity
      # Use Current.platform (set by middleware for web/API requests) with
      # fallback to host platform for background job mailer sends.
      # Set @platform ivar so mailer templates can reference it (e.g. @platform.name).
      @platform ||= ::Current.platform || BetterTogether::Platform.find_by(host: true)

      self.time_zone ||= time_zone || @platform&.time_zone || Rails.application.config.time_zone
      self.locale ||= locale || I18n.locale || @platform&.locale || I18n.default_locale

      # Set time zone and locale either from platform or passed in by child mailers
      Time.use_zone(time_zone) do
        I18n.with_locale(locale, &)
      end
    end
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/PerceivedComplexity

    # Parse a raw URL string and return Rails url_options components (host:, protocol:, port:).
    # Handles full URLs (https://example.com/path) — Rails expects host: to be hostname-only.
    # rubocop:disable Metrics/AbcSize
    def resolve_url_options(raw_url)
      uri = URI.parse(raw_url.to_s)
      opts = { host: uri.host.presence || raw_url.to_s }
      opts[:protocol] = uri.scheme if uri.scheme.present?
      opts[:port] = uri.port if uri.port && !default_port?(uri.scheme, uri.port)
      opts
    rescue URI::InvalidURIError
      { host: raw_url.to_s }
    end
    # rubocop:enable Metrics/AbcSize

    def default_port?(scheme, port)
      (scheme == 'https' && port == 443) || (scheme == 'http' && port == 80)
    end
  end
end
