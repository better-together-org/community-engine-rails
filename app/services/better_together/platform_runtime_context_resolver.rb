# frozen_string_literal: true

module BetterTogether
  # Resolves the runtime platform context for requests, jobs, and mailers.
  #
  # This is intentionally a small foundation layer: it centralizes host/platform
  # resolution and surfaces tenant schema metadata only for internal platforms.
  # Actual schema switching remains a later implementation step.
  class PlatformRuntimeContextResolver
    Result = Struct.new(
      :platform,
      :platform_domain,
      :tenant_schema,
      :source
    ) do
      def resolved?
        platform.present?
      end

      def domain_matched?
        platform_domain.present?
      end
    end

    def self.for_host(hostname, fallback_to_host: true)
      domain = ::BetterTogether::PlatformDomain.resolve(hostname)
      platform = domain&.platform
      source = domain.present? ? :platform_domain : :none

      if platform.blank? && fallback_to_host
        platform = host_platform
        source = :host_platform if platform.present?
      end

      build_result(platform:, platform_domain: domain, source:)
    end

    def self.for_platform(platform_or_id, fallback_to_host: false)
      platform = resolve_platform(platform_or_id)
      source = platform.present? ? :explicit_platform : :none

      if platform.blank? && fallback_to_host
        platform = host_platform
        source = :host_platform if platform.present?
      end

      build_result(platform:, platform_domain: nil, source:)
    end

    def self.build_result(platform:, platform_domain:, source:)
      Result.new(platform:, platform_domain:, tenant_schema: tenant_schema_for(platform), source:)
    end
    private_class_method :build_result

    def self.tenant_schema_for(platform)
      return unless platform&.internal?

      platform.tenant_schema.presence
    end
    private_class_method :tenant_schema_for

    def self.resolve_platform(platform_or_id)
      return platform_or_id if platform_or_id.is_a?(::BetterTogether::Platform)
      return if platform_or_id.blank?

      ::BetterTogether::Platform.find_by(id: platform_or_id)
    end
    private_class_method :resolve_platform

    def self.host_platform
      id = Rails.cache.fetch('better_together/host_platform_id', expires_in: 5.minutes) do
        ::BetterTogether::Platform.where(host: true).pick(:id)
      end
      id ? ::BetterTogether::Platform.find_by(id:) : nil
    end
    private_class_method :host_platform
  end
end
