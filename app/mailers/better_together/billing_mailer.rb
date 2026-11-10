# frozen_string_literal: true

module BetterTogether
  # Email for billing notifications, sent for Billing::Notifier.
  #
  # One message shape for every kind: what happened, in the reader's language, the order summary when the
  # message is about an order, and a link into the app. The summary is the same one the order pages show
  # (lines, each tax, the total, registration numbers). A buyer's order emails also carry it as a PDF invoice or
  # receipt, built from the same summary. It carries no payment instructions, no payee details
  # and no event payloads, so a forwarded or intercepted email cannot be used to redirect a payment.
  class BillingMailer < ApplicationMailer
    helper BetterTogether::BillingHelper
    helper BetterTogether::BillingSummaryHelper

    def notification # rubocop:disable Metrics/AbcSize
      @recipient = params[:recipient]
      @notifier = params[:notifier]
      @platform = @notifier.record.try(:platform)
      use_recipient_preferences

      I18n.with_locale(locale || I18n.locale) do
        write_message
        attach_documents
        mail(to: params[:address].presence || @recipient.email, subject: @title)
      end
    end

    private

    def use_recipient_preferences
      self.locale = @recipient.locale if @recipient.respond_to?(:locale)
      self.time_zone = @recipient.time_zone if @recipient.respond_to?(:time_zone)
    end

    # What the email says: words, the order summary and a link into the app, never payment details.
    def write_message
      @title = @notifier.title
      @body = @notifier.body
      @summary = @notifier.order_summary
      @url = absolute(@notifier.url)
      @business = Pay.business_name.presence
      # Pay hands the address back as a Mail::Address, which is never blank, so ask for the address itself.
      @support_email = Pay.support_email.try(:address).presence
    end

    # The invoice or receipt as a PDF, built from the same summary as the email and in the same language.
    def attach_documents
      @notifier.documents.each do |document|
        attachments[document.filename.to_s] = { mime_type: 'application/pdf', content: document.pdf }
      end
    end

    def absolute(path)
      options = default_url_options
      "#{options[:protocol] || 'https'}://#{options[:host]}#{":#{options[:port]}" if options[:port]}#{path}"
    end
  end
end
