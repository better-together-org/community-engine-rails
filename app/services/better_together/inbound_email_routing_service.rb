# frozen_string_literal: true

module BetterTogether
  # Resolves inbound email aliases into CE community, membership-request, or agent targets.
  class InboundEmailRoutingService # rubocop:todo Metrics/ClassLength
    def initialize(inbound_email, scanner_runner: nil)
      @inbound_email = inbound_email
      @mail = inbound_email.mail
      @scanner_runner = scanner_runner
    end

    def route!
      sender = primary_sender
      resolution = resolve_recipient(sender)
      body_plain = extract_body_plain

      Current.set(platform: resolution.platform) do
        BetterTogether::InboundEmailMessage.transaction do
          message = BetterTogether::InboundEmailMessage.create!(message_attributes_for(resolution, sender:, body_plain:))
          screening_result = screen_message!(message, resolution:, sender:, body_plain:)
          next message unless screening_result.allow_routing?

          routed_record = route_to_target(resolution, sender:, body_plain:)
          message.update!(routed_record:, status: 'routed') if routed_record.present?
          message
        end
      end
    end

    private

    def message_attributes_for(resolution, sender:, body_plain:)
      route_attributes_for(resolution).merge(
        sender_attributes_for(sender),
        recipient_attributes_for(resolution),
        {
          subject: @mail.subject.to_s,
          body_plain:
        }
      )
    end

    def route_attributes_for(resolution)
      {
        inbound_email: @inbound_email,
        route_kind: resolution.route_kind,
        status: initial_status_for(resolution),
        platform: resolution.platform,
        target: resolution.target
      }
    end

    def sender_attributes_for(sender)
      {
        sender_email: sender.address,
        sender_name: sender.display_name.presence,
        message_id: @mail.message_id.to_s.presence || @inbound_email.message_id
      }
    end

    def recipient_attributes_for(resolution)
      {
        recipient_address: resolution.recipient_address,
        recipient_local_part: resolution.recipient_local_part,
        recipient_domain: resolution.recipient_domain
      }
    end

    def resolve_recipient(sender)
      BetterTogether::InboundEmailResolutionService.new(primary_recipient, sender:).resolve
    end

    def initial_status_for(resolution) = resolution.route_kind == 'unresolved' ? 'rejected' : 'received'

    def screen_message!(message, resolution:, sender:, body_plain:)
      BetterTogether::ContentSecurity::MailScreeningService
        .new(
          inbound_email: @inbound_email,
          mail: @mail,
          resolution:,
          sender:,
          body_plain:,
          scanner_runner: @scanner_runner
        )
        .screen!(message)
    end

    def route_to_target(resolution, sender:, body_plain:)
      case resolution.route_kind
      when 'membership_request'
        create_membership_request!(resolution.target, sender:, body_plain:)
      when 'reply'
        create_reply!(resolution.target, body_plain:)
      end
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

    # Reference implementation for reply-by-email: comment-notification replies only. The
    # token's repliable is whatever record the originating notification pointed at (currently
    # always a Commentable, matching CommentMailer#added) -- a future notification type that
    # wants to support replies would need its own branch here, not a generic dispatch, since
    # "what does a reply create" is inherently notification-type-specific.
    def create_reply!(token, body_plain:)
      comment = token.repliable.comments.create!(creator: token.recipient, content: body_plain)
      token.consume!
      comment
    end

    def primary_sender = mail_address_from(:from, 'missing sender address')

    def primary_recipient = mail_address_from(:to, 'missing recipient address')

    def mail_address_from(field, error_message)
      address = Array(@mail.public_send(field)).first
      raise ArgumentError, error_message if address.blank?

      Mail::Address.new(address)
    end

    def extract_body_plain = @mail.multipart? ? multipart_body_plain : @mail.body.decoded.to_s.strip

    def multipart_body_plain
      text_part = @mail.text_part&.decoded.to_s.strip
      return text_part if text_part.present?

      ActionController::Base.helpers.strip_tags(@mail.html_part&.decoded.to_s).strip
    end
  end
end
