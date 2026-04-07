# frozen_string_literal: true

module BetterTogether
  # Resolves inbound email aliases into CE community, membership-request, or agent targets.
  class InboundEmailRoutingService
    Resolution = Struct.new(:route_kind, :target, :recipient_address, :recipient_local_part, :recipient_domain)
    ROUTE_PATTERNS = {
      'community' => /\Acommunity\+(.+)\z/,
      'agent' => /\Aagent\+(.+)\z/,
      'membership_request' => /\Arequests\+(.+)\z/
    }.freeze

    def initialize(inbound_email)
      @inbound_email = inbound_email
      @mail = inbound_email.mail
    end

    def route!
      resolution = resolve_recipient
      sender = primary_sender
      body_plain = extract_body_plain

      BetterTogether::InboundEmailMessage.transaction do
        message = BetterTogether::InboundEmailMessage.create!(message_attributes_for(resolution, sender:, body_plain:))

        routed_record = route_to_target(resolution, sender:, body_plain:)
        message.update!(routed_record:, status: 'routed') if routed_record.present?
        message
      end
    end

    private

    def message_attributes_for(resolution, sender:, body_plain:)
      {
        inbound_email: @inbound_email,
        route_kind: resolution.route_kind,
        status: initial_status_for(resolution),
        target: resolution.target,
        sender_email: sender.address,
        sender_name: sender.display_name.presence,
        message_id: @mail.message_id.to_s.presence || @inbound_email.message_id,
        recipient_address: resolution.recipient_address,
        recipient_local_part: resolution.recipient_local_part,
        recipient_domain: resolution.recipient_domain,
        subject: @mail.subject.to_s,
        body_plain:
      }
    end

    def resolve_recipient
      address = primary_recipient
      local_part = address.local.downcase
      domain = address.domain.to_s.downcase
      route_kind, target = route_target_for(local_part)
      resolution_for(address, local_part:, domain:, route_kind:, target:)
    end

    def initial_status_for(resolution) = resolution.route_kind == 'unresolved' ? 'rejected' : 'received'

    def resolution_for(address, local_part:, domain:, route_kind:, target:)
      Resolution.new(route_kind, target, address.address.downcase, local_part, domain)
    end

    def route_target_for(local_part)
      ROUTE_PATTERNS.each do |route_kind, pattern|
        next unless (match = local_part.match(pattern))

        return [route_kind, target_for(route_kind, match[1])]
      end

      ['unresolved', nil]
    end

    def target_for(route_kind, identifier)
      return community_by_slug(identifier) if %w[community membership_request].include?(route_kind)

      route_kind == 'agent' ? agent_by_identifier(identifier) : nil
    end

    def route_to_target(resolution, sender:, body_plain:)
      resolution.route_kind == 'membership_request' ? create_membership_request!(resolution.target, sender:, body_plain:) : nil
    end

    def create_membership_request!(community, sender:, body_plain:)
      BetterTogether::Joatu::MembershipRequest.create!(
        target: community,
        status: 'open',
        urgency: 'normal',
        requestor_name: sender.display_name.presence,
        requestor_email: sender.address,
        description: body_plain
      )
    end

    def primary_sender
      address = Array(@mail.from).first
      raise ArgumentError, 'missing sender address' if address.blank?

      Mail::Address.new(address)
    end

    def primary_recipient
      address = Array(@mail.to).first
      raise ArgumentError, 'missing recipient address' if address.blank?

      Mail::Address.new(address)
    end

    def extract_body_plain
      return multipart_body_plain if @mail.multipart?

      @mail.body.decoded.to_s.strip
    end

    def multipart_body_plain
      text_part = @mail.text_part&.decoded.to_s.strip
      return text_part if text_part.present?

      ActionController::Base.helpers.strip_tags(@mail.html_part&.decoded.to_s).strip
    end

    def community_by_slug(slug)
      BetterTogether::Community.friendly.find(slug)
    end

    def agent_by_identifier(identifier)
      BetterTogether::Robot.active.global.by_identifier(identifier).first ||
        BetterTogether::Person.find_by!(identifier:)
    end
  end
end
