# frozen_string_literal: true

module BetterTogether
  # Accepts raw RFC822 mail from the shared BTS ingress router and records it in Action Mailbox.
  class InboundEmailsController < ActionMailbox::BaseController
    skip_before_action :ensure_configured
    before_action :authenticate_ingress_password
    before_action :require_valid_rfc822_message

    def create
      ActionMailbox::InboundEmail.create_and_extract_message_id!(request.body.read)
      head :no_content
    end

    private

    def authenticate_ingress_password
      authenticate_or_request_with_http_basic do |username, password|
        username == 'actionmailbox' &&
          BetterTogether.inbound_email_password.present? &&
          ActiveSupport::SecurityUtils.secure_compare(password, BetterTogether.inbound_email_password)
      end
    end

    def require_valid_rfc822_message
      head :unsupported_media_type unless request.media_type == 'message/rfc822'
    end
  end
end
