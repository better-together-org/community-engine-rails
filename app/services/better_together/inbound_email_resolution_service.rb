# frozen_string_literal: true

module BetterTogether
  # Resolves an inbound recipient address into a tenant-scoped CE routing target.
  class InboundEmailResolutionService # rubocop:todo Metrics/ClassLength
    Resolution = Struct.new(:route_kind, :target, :platform, :recipient_address, :recipient_local_part, :recipient_domain)

    ROUTE_PATTERNS = {
      'community' => /\Acommunity\+(.+)\z/,
      'agent' => /\Aagent\+(.+)\z/,
      'membership_request' => /\Arequests\+(.+)\z/,
      'reply' => /\Areply\+(.+)\z/
    }.freeze

    # Reply tokens are opaque has_secure_token values (case-sensitive), unlike the other
    # route kinds' slugs/identifiers (case-insensitive by convention) — see #identifier_for.
    REPLY_TOKEN_ORIGINAL_CASE_PATTERN = /\Areply\+(.+)\z/i

    # @param sender [Mail::Address, nil] the parsed From: address. Required for agent+
    #   resolution to verify the sender is actually the person being addressed — without it,
    #   agent+<identifier>@ resolution always fails closed (see #sender_matches_person?).
    # @param mail [Mail::Message, nil] the raw inbound message, used to read the SPF/DKIM/DMARC
    #   results the mail-receiver's Postfix milters already stamp onto it (see
    #   InboundMailAuthentication). Optional and fail-safe: without it, sender_matches_person?
    #   behaves exactly as it did before this signal existed.
    def initialize(address, sender: nil, mail: nil)
      @address = address
      @sender = sender
      @mail = mail
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

        return [route_kind, target_for(route_kind, identifier_for(route_kind, match), platform)]
      end

      ['unresolved', nil]
    end

    # Re-matches the ORIGINAL (non-downcased) local part for reply+ so the captured token
    # keeps its real case; other route kinds use the already-downcased match as before.
    def identifier_for(route_kind, downcased_match)
      return downcased_match[1] unless route_kind == 'reply'

      @address.local.match(REPLY_TOKEN_ORIGINAL_CASE_PATTERN)&.[](1) || downcased_match[1]
    end

    def target_for(route_kind, identifier, platform)
      return membership_request_target(identifier, platform) if route_kind == 'membership_request'
      return community_by_slug(identifier, platform) if route_kind == 'community'
      return reply_token_target(identifier, platform) if route_kind == 'reply'

      route_kind == 'agent' ? agent_by_identifier(identifier, platform) : nil
    end

    # reply+<token>@ resolution does NOT trust the From: header the way agent+ does — the
    # token itself (opaque, unique, single-use, DB-looked-up) is the authorization. The
    # sender check here is defense in depth (a leaked token alone shouldn't be enough), not
    # the primary security boundary the way it is for agent+.
    def reply_token_target(token_value, platform)
      token = BetterTogether::InboundEmailReplyToken.active.find_by(token: token_value)
      return nil unless token && token.platform_id == platform.id && sender_matches_person?(token.recipient)

      token
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
    # is often guessable/public. Without this check, anyone could cause a message to be
    # attributed to (routed as if sent by) an arbitrary real person just by guessing their
    # identifier. Robots have no equivalent sender concept to verify against, so tenant_robot
    # resolution above is unaffected.
    def verified_tenant_person(identifier, platform)
      person = BetterTogether::Person
               .joins(:person_platform_memberships)
               .merge(BetterTogether::PersonPlatformMembership.active.where(joinable: platform))
               .find_by(identifier:)
      return nil unless person && sender_matches_person?(person)

      person
    end

    # Two independent checks, both required: the From: address must match the target person's
    # real email (string comparison -- this alone is spoofable, since nothing about SMTP
    # requires a From: header to be genuine), AND none of SPF/DKIM/DMARC may have explicitly
    # failed (a cryptographic/protocol-level signal a forged From: usually can't produce, since
    # the attacker doesn't control the impersonated domain's DKIM keys). Either check alone is
    # insufficient; together they cover both "right address, unverified" and "verified,
    # wrong/no address" — see InboundMailAuthentication for why a merely absent SPF/DKIM/DMARC
    # result (most domains don't publish them) does NOT count as a failure here.
    def sender_matches_person?(person)
      address_matches_person?(person) && !authentication.hard_fail?
    end

    def address_matches_person?(person)
      sender_email = @sender&.address.to_s.downcase
      person_email = person.email.to_s.downcase

      sender_email.present? && person_email.present? && sender_email == person_email
    end

    def authentication
      @authentication ||= BetterTogether::InboundMailAuthentication.new(@mail)
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
