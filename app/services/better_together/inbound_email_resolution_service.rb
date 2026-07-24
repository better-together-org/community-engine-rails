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

    # @param sender [Mail::Address, nil] the parsed From: address. Required for agent+
    #   resolution to verify the sender is actually the person being addressed — without it,
    #   agent+<identifier>@ resolution always fails closed (see #sender_matches_person?).
    def initialize(address, sender: nil)
      @address = address
      @sender = sender
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
      platform = BetterTogether::PlatformDomain.resolve(hostname)&.platform || platform_from_host_url(hostname)

      platform if platform&.allow_inbound_mail?
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
      return membership_request_target(identifier, platform) if route_kind == 'membership_request'
      return community_by_slug(identifier, platform) if route_kind == 'community'

      route_kind == 'agent' ? agent_by_identifier(identifier, platform) : nil
    end

    # requests+ additionally requires the target community to have membership requests
    # enabled — community_by_slug alone only proves the alias points at the platform's own
    # community, not that the community/platform actually opted in to accepting them.
    def membership_request_target(slug, platform)
      community = community_by_slug(slug, platform)
      return nil unless community&.membership_requests_enabled?(platform:)

      community
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
      tenant_robot(identifier, platform) || verified_tenant_person(identifier, platform)
    end

    # Person resolution is intentionally sender-verified: the local-part identifier alone
    # is often guessable/public, and nothing else in the inbound-mail pipeline authenticates
    # the From: header (no SPF/DKIM/DMARC checking exists upstream). Without this check,
    # anyone could cause a message to be attributed to (routed as if sent by) an arbitrary
    # real person just by guessing their identifier. Robots have no equivalent sender concept
    # to verify against, so tenant_robot resolution above is unaffected.
    def verified_tenant_person(identifier, platform)
      person = BetterTogether::Person
               .joins(:person_platform_memberships)
               .merge(BetterTogether::PersonPlatformMembership.active.where(joinable: platform))
               .find_by(identifier:)
      return nil unless person && sender_matches_person?(person)

      person
    end

    def sender_matches_person?(person)
      sender_email = @sender&.address.to_s.downcase
      person_email = person.email.to_s.downcase

      sender_email.present? && person_email.present? && sender_email == person_email
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
