# frozen_string_literal: true

module BetterTogether
  # Decides whether a page may be measured by third-party vendors (analytics, session replay, ads).
  # The answer is closed by default: a page is tracked only when it is plainly public. Extension
  # gems ask the view helper `third_party_tracking_allowed?` before emitting vendor scripts.
  module ThirdPartyTracking
    extend ActiveSupport::Concern

    # Query parameters that carry secrets or one-time codes; a URL holding one is never sent out.
    SENSITIVE_PARAMS = %w[
      invitation_code token reset_password_token confirmation_token unlock_token access_token code state
    ].freeze

    class_methods do
      # Never track these actions, whatever the record. Accepts the before_action options (only:, if:).
      def skip_third_party_tracking(**)
        before_action(:block_third_party_tracking!, **)
      end
    end

    private

    def block_third_party_tracking!
      @third_party_tracking_blocked = true
    end

    def third_party_tracking_allowed?
      third_party_tracking_exclusion.nil?
    end

    # The reason this request is excluded, or nil when it may be tracked.
    def third_party_tracking_exclusion(check_response: true) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      return :explicit if @third_party_tracking_blocked
      return :not_a_read unless request.get? || request.head?
      return :error_response if check_response && !response_successful?
      return :private_platform unless platform_publicly_visible?
      return :sensitive_params if sensitive_params?
      return :private_record unless record_public_or_anonymous?

      registered_exclusion
    rescue StandardError => e
      Rails.logger.warn("third_party_tracking: failing closed (#{e.class}: #{e.message})")
      :error
    end

    # True when the page is private or protected, judged without the response status (an error page
    # for a private record is still private). Error reporters use it to stay at the essential tier.
    def private_page?
      !third_party_tracking_exclusion(check_response: false).nil?
    end

    def response_successful?
      response.successful?
    end

    def platform_publicly_visible?
      platform = helpers.host_platform
      !platform.respond_to?(:privacy_public?) || platform.privacy_public?
    end

    def sensitive_params?
      request.query_parameters.keys.map(&:to_s).intersect?(SENSITIVE_PARAMS) || params[:invitation_code].present?
    end

    # An anonymous visitor can only be looking at something public. A signed-in person may be looking
    # at community or private content (or a list that mixes it), so we need the page's own record to
    # be public before trusting it.
    def record_public_or_anonymous?
      record = @resource
      return record.privacy_public? if record.respond_to?(:privacy_public?)

      current_user.blank?
    end

    def registered_exclusion
      BetterTogether.third_party_tracking_exclusions.each do |key, rule|
        return key if rule.call(self)
      end
      nil
    end
  end
end
