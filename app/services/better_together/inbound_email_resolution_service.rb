# frozen_string_literal: true

module BetterTogether
  # Resolves an inbound recipient address into a tenant-scoped CE routing target.
  class InboundEmailResolutionService
    Resolution = Struct.new(:route_kind, :target, :platform, :recipient_address, :recipient_local_part, :recipient_domain)

    ROUTE_PATTERNS = {
      'community' => /\Acommunity\+(.+)\z/,
      'agent' => /\Aagent\+(.+)\z/,
      'membership_request' => /\Arequests\+(.+)\z/
    }.freeze

    def initialize(address)
      @address = address
    end

    def resolve
      platform = platform_for
      route_kind, target = route_target_for(platform)
      return build_resolution('unresolved', nil, platform) if target.blank?

      build_resolution(route_kind, target, platform)
    end

    private

    def platform_for
      hostname = BetterTogether::PlatformDomain.normalize_hostname(@address.domain.to_s.downcase)

      BetterTogether::PlatformDomain.resolve(hostname)&.platform || platform_from_host_url(hostname)
    end

    def route_target_for(platform)
      return ['unresolved', nil] if platform.blank?

      ROUTE_PATTERNS.each do |route_kind, pattern|
        next unless (match = @address.local.downcase.match(pattern))

        return [route_kind, target_for(route_kind, match[1], platform)]
      end

      ['unresolved', nil]
    end

    def target_for(route_kind, identifier, platform)
      return community_by_slug(identifier, platform) if %w[community membership_request].include?(route_kind)

      route_kind == 'agent' ? agent_by_identifier(identifier, platform) : nil
    end

    def community_by_slug(slug, platform)
      community = BetterTogether::Community.find_by(identifier: slug)
      community ||= BetterTogether::Community.friendly.find(slug)
      return community if community.present? && platform.community == community

      nil
    rescue ActiveRecord::RecordNotFound
      nil
    end

    def agent_by_identifier(identifier, platform)
      tenant_robot(identifier, platform) ||
        BetterTogether::Person
          .joins(:person_platform_memberships)
          .merge(BetterTogether::PersonPlatformMembership.active.where(joinable: platform))
          .find_by(identifier:)
    end

    def build_resolution(route_kind, target, platform)
      self.class::Resolution.new(
        route_kind,
        target,
        platform,
        @address.address.downcase,
        @address.local.downcase,
        @address.domain.to_s.downcase
      )
    end

    def tenant_robot(identifier, platform)
      return unless defined?(BetterTogether::Robot)

      BetterTogether::Robot.resolve(identifier:, platform:)
    end

    def platform_from_host_url(hostname)
      BetterTogether::Platform.internal.find_each.find do |platform|
        platform_hostname(platform) == hostname
      end
    end

    def platform_hostname(platform)
      BetterTogether::PlatformDomain.normalize_hostname(URI.parse(platform.host_url.to_s).host)
    rescue URI::InvalidURIError
      nil
    end
  end
end
