# frozen_string_literal: true

module BetterTogether
  # Resolves the OAuth client credentials for a catalog provider on a platform:
  # the platform's own row, then the host platform's row, then ENV.
  class IdentityProviderCredentials
    REDACTED = '[FILTERED]'

    # Carries the client secret to OmniAuth; never prints it via inspect, to_s, to_h or JSON.
    Result = Struct.new(:client_id, :client_secret, :scope, :options, keyword_init: true) do
      def inspect
        secret = client_secret.present? ? IdentityProviderCredentials::REDACTED : 'nil'
        "#<#{self.class.name} client_id=#{client_id.inspect} client_secret=#{secret} scope=#{scope.inspect}>"
      end
      alias_method :to_s, :inspect

      def to_h(*)
        super.merge(client_secret: client_secret.present? ? IdentityProviderCredentials::REDACTED : nil)
      end

      def as_json(*)
        to_h.as_json
      end
    end

    # Credentials for a provider on one platform domain, or nil when the provider is not
    # configured for that domain. There is no fallback to another platform's configuration:
    # the domain must be on the configuration's allow-list. Environment variables are the
    # host platform's own configuration and apply to the host platform's domains only.
    def self.resolve(key, domain:)
      new(key, domain).resolve
    end

    def self.configured?(key, domain:)
      resolve(key, domain:)&.then { |r| r.client_id.present? && r.client_secret.present? } || false
    end

    def initialize(key, domain)
      @provider = IdentityProviders.fetch(key)
      @domain = domain
    end

    def resolve
      return unless @domain

      row = row_for_domain
      return (row.enabled? ? from_row(row) : nil) if row

      from_env if @domain.platform&.host?
    end

    private

    def row_for_domain
      PlatformIdentityProvider.where(strategy: @provider.key.to_s)
                              .joins(:provider_domains)
                              .find_by(PlatformIdentityProviderDomain.table_name => { platform_domain_id: @domain.id })
    end

    def from_row(row)
      Result.new(client_id: row.client_id, client_secret: row.client_secret,
                 scope: row.scopes.presence || @provider.scope, options: row.options || {})
    end

    def from_env
      Result.new(client_id: @provider.env_id && ENV.fetch(@provider.env_id, nil),
                 client_secret: @provider.env_secret && ENV.fetch(@provider.env_secret, nil),
                 scope: @provider.scope, options: {})
    rescue ActiveRecord::ActiveRecordError
      Result.new(scope: @provider.scope, options: {})
    end
  end
end
