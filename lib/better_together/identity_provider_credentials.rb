# frozen_string_literal: true

module BetterTogether
  # Resolves the OAuth client credentials for a catalog provider on a platform:
  # the platform's own row, then the host platform's row, then ENV.
  class IdentityProviderCredentials
    REDACTED = '[FILTERED]'

    # Carries the client secret to OmniAuth; never prints it via inspect, to_s, to_h or JSON.
    Result = Struct.new(:client_id, :client_secret, :scope, :options, :provider_id, :identity_platform,
                        :trust_verified_email, keyword_init: true) do
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
    #
    # Issuer-based providers (OpenID Connect) may have several configurations on one domain, one per
    # issuer. `provider_id` names the configuration the user picked; without it a domain with more than
    # one configuration resolves to nothing rather than guessing.
    def self.resolve(key, domain:, provider_id: nil)
      new(key, domain, provider_id).resolve
    end

    # Providers configured through environment variables for the host platform: for each, the
    # host domains the environment still serves (those no provider row claims). Never returns values.
    EnvProvider = Struct.new(:provider, :domains, keyword_init: true)

    def self.env_providers(platform)
      return [] unless platform&.host?

      domains = platform.platform_domains.active.to_a
      IdentityProviders.registry.values.select { |provider| env_configured?(provider) }.map do |provider|
        EnvProvider.new(provider:, domains: domains.reject { |d| claimed?(provider, d) })
      end
    end

    def self.env_configured?(provider)
      return false unless provider.env_id && provider.env_secret

      ENV.fetch(provider.env_id, nil).present? && ENV.fetch(provider.env_secret, nil).present?
    end
    private_class_method :env_configured?

    def self.claimed?(provider, domain)
      PlatformIdentityProviderDomain.joins(:platform_identity_provider)
                                    .exists?(platform_domain_id: domain.id,
                                             PlatformIdentityProvider.table_name => { strategy: provider.key.to_s })
    end
    private_class_method :claimed?

    def self.configured?(key, domain:, provider_id: nil)
      resolve(key, domain:, provider_id:)&.then { |r| r.client_id.present? && r.client_secret.present? } || false
    end

    # The enabled configurations serving a domain, for building one sign-in button each.
    def self.choices(key, domain:)
      return [] unless domain

      new(key, domain, nil).rows.select(&:enabled?)
    end

    def initialize(key, domain, provider_id = nil)
      @provider = IdentityProviders.fetch(key)
      @domain = domain
      @provider_id = provider_id.presence
    end

    def resolve
      return unless @domain

      rows = self.rows
      return from_env if env_applies?(rows)

      row = pick(rows)
      row&.enabled? ? from_row(row) : nil
    end

    def rows
      return [] unless @domain

      PlatformIdentityProvider.where(strategy: @provider.key.to_s)
                              .joins(:provider_domains)
                              .where(PlatformIdentityProviderDomain.table_name => { platform_domain_id: @domain.id })
                              .includes(:provider_platform).to_a
    end

    private

    # Environment variables are the host platform's own configuration, used only when no row serves the domain.
    def env_applies?(rows)
      rows.empty? && @provider_id.nil? && @domain.platform&.host?
    end

    def pick(rows)
      return rows.find { |row| row.id == @provider_id } if @provider_id

      rows.one? ? rows.first : nil
    end

    def from_row(row)
      Result.new(client_id: row.client_id, client_secret: row.client_secret,
                 scope: row.scopes.presence || @provider.scope,
                 options: (row.options || {}).except('label', 'trust_verified_email'),
                 provider_id: row.id, trust_verified_email: row.trust_verified_email?,
                 identity_platform: (row.provider_platform if @provider.requires_issuer))
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
