# frozen_string_literal: true

module BetterTogether
  class FederationAccessTokenIssuer
    DEFAULT_EXPIRES_IN = 15.minutes

    Result = Struct.new(
      :access_token_record,
      :access_token,
      :scope,
      :expires_in,
      keyword_init: true
    )

    def self.call(connection:, requested_scopes:, expires_in: DEFAULT_EXPIRES_IN)
      new(connection:, requested_scopes:, expires_in:).call
    end

    def initialize(connection:, requested_scopes:, expires_in: DEFAULT_EXPIRES_IN)
      @connection = connection
      @requested_scopes = requested_scopes
      @expires_in = normalize_expires_in(expires_in)
    end

    def call
      raise ArgumentError, 'connection is required' unless connection

      auth_result = ::BetterTogether::FederationScopeAuthorizer.call(
        source_platform: connection.source_platform,
        target_platform: connection.target_platform,
        requested_scopes:
      )

      raise ArgumentError, 'requested scopes are not authorized' unless auth_result.allowed?
      raise ArgumentError, 'at least one scope is required' if auth_result.granted_scopes.empty?

      access_token_record = ::BetterTogether::FederationAccessToken.create!(
        platform_connection: connection,
        scopes: auth_result.granted_scopes.join(' '),
        expires_at: Time.current + expires_in
      )

      Result.new(
        access_token_record:,
        access_token: access_token_record.token,
        scope: access_token_record.scopes,
        expires_in: expires_in.to_i
      )
    end

    private

    attr_reader :connection, :requested_scopes, :expires_in

    def normalize_expires_in(value)
      seconds = value.to_i
      seconds.positive? ? seconds.seconds : DEFAULT_EXPIRES_IN
    end
  end
end
