# frozen_string_literal: true

module BetterTogether
  # Resolves the OAuth client credentials for a catalog provider on a platform:
  # the platform's own row, then the host platform's row, then ENV.
  class IdentityProviderCredentials
    Result = Struct.new(:client_id, :client_secret, :scope, :options, keyword_init: true)

    def self.resolve(key, platform: nil)
      new(key, platform).resolve
    end

    def self.configured?(key, platform: nil)
      resolve(key, platform:).then { |r| r.client_id.present? && r.client_secret.present? }
    end

    def initialize(key, platform)
      @provider = IdentityProviders.fetch(key)
      @platform = platform
    end

    def resolve
      row = row_for(@platform) || row_for(host_platform)
      return from_row(row) if row

      from_env
    end

    private

    def row_for(platform)
      return unless platform

      PlatformIdentityProvider.enabled.find_by(platform_id: platform.id, strategy: @provider.key.to_s)
    end

    def host_platform
      Platform.find_by(host: true)
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
