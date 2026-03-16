# frozen_string_literal: true

module BetterTogether
  # Issues short-lived OAuth access tokens for a platform connection.
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

      auth_result = authorize_scopes!
      record = create_access_token_record(auth_result)
      build_result(record)
    end

    private

    attr_reader :connection, :requested_scopes, :expires_in

    def authorize_scopes!
      result = ::BetterTogether::FederationScopeAuthorizer.call(
        source_platform: connection.source_platform,
        target_platform: connection.target_platform,
        requested_scopes:
      )
      raise ArgumentError, 'requested scopes are not authorized' unless result.allowed?
      raise ArgumentError, 'at least one scope is required' if result.granted_scopes.empty?

      result
    end

    def create_access_token_record(auth_result)
      ::BetterTogether::FederationAccessToken.create!(
        platform_connection: connection,
        scopes: auth_result.granted_scopes.join(' '),
        expires_at: Time.current + expires_in
      )
    end

    def build_result(record)
      Result.new(
        access_token_record: record,
        access_token: record.token,
        scope: record.scopes,
        expires_in: expires_in.to_i
      )
    end

    def normalize_expires_in(value)
      seconds = value.to_i
      seconds.positive? ? seconds.seconds : DEFAULT_EXPIRES_IN
    end
  end
end
