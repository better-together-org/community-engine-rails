# frozen_string_literal: true

module BetterTogether
  # Sends email notifications when a comment is added to the recipient's content
  class CommentMailer < ApplicationMailer
    def added
      @comment = params[:comment]
      @commentable = @comment.commentable
      @recipient = params[:recipient]

      self.locale = @recipient.locale
      self.time_zone = @recipient.time_zone

      set_reply_to_header

      mail(to: @recipient.email, subject: t('better_together.comment_mailer.added.subject'))
    end

    private

    def set_reply_to_header
      headers['Reply-To'] = reply_to_address if reply_by_email_available?
    end

    # Reply-by-email requires a resolvable inbound-mail domain and a recipient who can
    # actually be sender-verified on reply (see InboundEmailResolutionService#reply_token_target)
    # -- falls back to no Reply-To (defaults to the From: address) rather than issuing a token
    # that could never be redeemed.
    def reply_by_email_available?
      @platform&.allow_inbound_mail? && inbound_mail_domain.present? && @recipient.email.present?
    end

    def reply_to_address
      token = BetterTogether::InboundEmailReplyToken.issue!(
        recipient: @recipient,
        repliable: @commentable,
        notification_type: 'comment_added',
        platform: @platform
      )
      token.reply_address(inbound_mail_domain)
    end

    def inbound_mail_domain
      @inbound_mail_domain ||= @platform&.primary_platform_domain&.hostname
    end
  end
end
