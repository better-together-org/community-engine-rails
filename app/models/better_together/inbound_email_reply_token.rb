# frozen_string_literal: true

module BetterTogether
  # A single-use, per-recipient token that authorizes a reply-by-email to act on a specific
  # notifiable record. Deliberately opaque (has_secure_token + DB lookup, mirroring
  # Invitation#token) rather than a signed/verifiable token: the security boundary for
  # reply-by-email is "does this exact token exist, belong to this sender, and remain
  # unconsumed" — not trust in any part of the inbound email itself. See
  # InboundEmailResolutionService#reply_token_target for the sender-binding check that makes
  # this actually safe (a leaked/guessed token alone is not sufficient; the mail's From:
  # address must also match the token's recipient).
  class InboundEmailReplyToken < PlatformRecord
    self.table_name = 'better_together_inbound_email_reply_tokens'

    has_secure_token :token

    belongs_to :recipient, class_name: 'BetterTogether::Person'
    belongs_to :repliable, polymorphic: true
    belongs_to :platform, class_name: 'BetterTogether::Platform', optional: true

    validates :notification_type, presence: true

    scope :active, lambda {
      where(consumed_at: nil).where(arel_table[:expires_at].eq(nil).or(arel_table[:expires_at].gt(Time.current)))
    }

    DEFAULT_LIFETIME = 30.days

    # platform: left unset by default -- PlatformScoped's before_validation callback
    # (assign_current_platform_if_available) resolves it from Current.platform/host platform,
    # same as every other PlatformRecord. Pass it explicitly only when issuing outside a
    # request/job context where Current.platform wouldn't already be set.
    def self.issue!(recipient:, repliable:, notification_type:, platform: nil)
      create!(
        recipient:,
        repliable:,
        notification_type:,
        platform:,
        expires_at: DEFAULT_LIFETIME.from_now
      )
    end

    def consumed?
      consumed_at.present?
    end

    def expired?
      expires_at.present? && expires_at <= Time.current
    end

    def usable?
      !consumed? && !expired?
    end

    def consume!
      update!(consumed_at: Time.current)
    end

    def reply_address(domain)
      "reply+#{token}@#{domain}"
    end
  end
end
