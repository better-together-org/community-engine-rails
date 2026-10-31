# frozen_string_literal: true

module BetterTogether
  # Email for billing notifications, sent for Billing::Notifier.
  #
  # One message shape for every kind: what happened, in the reader's language, and a link into the
  # app. It carries no payment instructions, no payee details and no event payloads, so a forwarded
  # or intercepted email cannot be used to redirect a payment.
  class BillingMailer < ApplicationMailer
    def notification
      @recipient = params[:recipient]
      @notifier = params[:notifier]
      @platform = @notifier.record.try(:platform)
      use_recipient_preferences

      I18n.with_locale(locale || I18n.locale) do
        write_message
        mail(to: @recipient.email, subject: @title)
      end
    end

    private

    def use_recipient_preferences
      self.locale = @recipient.locale if @recipient.respond_to?(:locale)
      self.time_zone = @recipient.time_zone if @recipient.respond_to?(:time_zone)
    end

    # What the email says. Only words and a link into the app, never payment details.
    def write_message
      @title = @notifier.title
      @body = @notifier.body
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
