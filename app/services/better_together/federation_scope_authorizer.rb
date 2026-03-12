# frozen_string_literal: true

module BetterTogether
  # Authorizes CE federation OAuth/API scopes against a directed platform connection.
  class FederationScopeAuthorizer
    SUPPORTED_SCOPE_RULES = {
      'identity.read' => ->(connection) { connection.login_enabled? },
      'person.profile.read' => ->(connection) { connection.allows_federation_scope?('profile_read') },
      'content.read' => ->(connection) { connection.api_read_enabled? },
      'content.feed.read' => ->(connection) { connection.api_read_enabled? && connection.mirrored_content_enabled? },
      'content.mirror.write' => ->(connection) { connection.api_write_enabled? && connection.mirrored_content_enabled? },
      'content.publish.write' => ->(connection) { connection.publish_back_enabled? }
    }.freeze

    Result = Struct.new(
      :connection,
      :requested_scopes,
      :granted_scopes,
      :denied_scopes,
      :unsupported_scopes,
      keyword_init: true
    ) do
      def allowed?
        denied_scopes.empty? && unsupported_scopes.empty?
      end
    end

    def self.call(source_platform:, target_platform:, requested_scopes:)
      new(source_platform:, target_platform:, requested_scopes:).call
    end

    def initialize(source_platform:, target_platform:, requested_scopes:)
      @source_platform = source_platform
      @target_platform = target_platform
      @requested_scopes = normalize_requested_scopes(requested_scopes)
    end

    def call
      connection = authorized_connection
      return empty_result(connection:) unless connection

      granted_scopes = []
      denied_scopes = []
      unsupported_scopes = []

      requested_scopes.each do |scope|
        rule = SUPPORTED_SCOPE_RULES[scope]

        if rule.nil?
          unsupported_scopes << scope
        elsif rule.call(connection)
          granted_scopes << scope
        else
          denied_scopes << scope
        end
      end

      Result.new(
        connection:,
        requested_scopes:,
        granted_scopes: granted_scopes.uniq,
        denied_scopes: denied_scopes.uniq,
        unsupported_scopes: unsupported_scopes.uniq
      )
    end

    private

    attr_reader :source_platform, :target_platform, :requested_scopes

    def authorized_connection
      ::BetterTogether::PlatformConnection.active.find_by(
        source_platform: source_platform,
        target_platform: target_platform
      )
    end

    def normalize_requested_scopes(scopes)
      Array(scopes)
        .flat_map { |scope| scope.to_s.split(/\s+/) }
        .map(&:strip)
        .reject(&:blank?)
        .uniq
    end

    def empty_result(connection:)
      Result.new(
        connection:,
        requested_scopes:,
        granted_scopes: [],
        denied_scopes: requested_scopes,
        unsupported_scopes: []
      )
    end
  end
end
