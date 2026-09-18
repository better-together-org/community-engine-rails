# frozen_string_literal: true

module BetterTogether
  # Authorizes CE federation OAuth/API scopes against a directed platform connection.
  class FederationScopeAuthorizer
    BASE_SCOPE_RULES = {
      'identity.read' => ->(connection) { connection.login_enabled? },
      'person.profile.read' => ->(connection) { connection.allows_federation_scope?('profile_read') },
      'content.read' => ->(connection) { connection.api_read_enabled? },
      'content.feed.read' => ->(connection) { connection.api_read_enabled? && connection.mirrored_content_enabled? },
      'linked_content.read' => ->(connection) { connection.linked_content_read_enabled? },
      'content.mirror.write' => ->(connection) { connection.api_write_enabled? && connection.mirrored_content_enabled? },
      'content.publish.write' => ->(connection) { connection.publish_back_enabled? }
    }.freeze

    class << self
      # Extension point for optional federation scopes (e.g. the Borgberry
      # extension's 'c3.exchange') owned by a gem that may not be bundled —
      # core never references scope names it doesn't itself implement.
      def register_scope_rule(name, &rule)
        self.additional_scope_rules = additional_scope_rules.merge(name.to_s => rule)
      end

      def scope_rules
        BASE_SCOPE_RULES.merge(additional_scope_rules)
      end
    end

    mattr_accessor :additional_scope_rules, default: {}

    Result = Struct.new(
      :connection,
      :requested_scopes,
      :granted_scopes,
      :denied_scopes,
      :unsupported_scopes
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

      scope_buckets = classify_scopes(connection)
      Result.new(connection:, requested_scopes:, **scope_buckets)
    end

    private

    attr_reader :source_platform, :target_platform, :requested_scopes

    def classify_scopes(connection)
      granted = []
      denied = []
      unsupported = []

      requested_scopes.each do |scope|
        rule = self.class.scope_rules[scope]
        if rule.nil?
          unsupported << scope
        elsif rule.call(connection)
          granted << scope
        else
          denied << scope
        end
      end

      { granted_scopes: granted.uniq, denied_scopes: denied.uniq, unsupported_scopes: unsupported.uniq }
    end

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
