# frozen_string_literal: true

module BetterTogether
  # Email for billing notifications, sent for Billing::Notifier.
  #
  # One message shape for every kind: what happened, in the reader's language, the order summary when the
  # message is about an order, and a link into the app. The summary is the same one the order pages show
  # (lines, each tax, the total, registration numbers). It carries no payment instructions, no payee details
  # and no event payloads, so a forwarded or intercepted email cannot be used to redirect a payment.
  class BillingMailer < ApplicationMailer
    helper BetterTogether::BillingHelper
    helper BetterTogether::BillingSummaryHelper

    def notification
      @recipient = params[:recipient]
      @notifier = params[:notifier]
      @platform = @notifier.record.try(:platform)
      use_recipient_preferences

      I18n.with_locale(locale || I18n.locale) do
        write_message
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
      @support_email = Pay.support_email.presence
    end

    def absolute(path)
      options = default_url_options
      "#{options[:protocol] || 'https'}://#{options[:host]}#{":#{options[:port]}" if options[:port]}#{path}"
    end
  end
end
