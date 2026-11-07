# frozen_string_literal: true

module BetterTogether
  module Billing
    # A steward gives a person store credit. Repeating the form (a double click) gives it once: the form
    # carries a token that becomes the grant's idempotency key. A steward cannot give themselves credit.
    class CreditGrantsController < ApplicationController
      include OwnerScoped

      after_action :verify_authorized

      def create
        authorize BetterTogether::Billing::CreditAccount, :grant?
        holder = BetterTogether::Person.find_by(id: params[:person_id])
        lot = holder && grant(holder)
        return back(:alert, 'grant_refused') unless lot

        redirect_to billing_credit_account_path(lot.account, locale: I18n.locale), notice: t('better_together.billing.credit.granted')
      end

      private

      def back(kind, key)
        redirect_to billing_credit_accounts_path(locale: I18n.locale, handle: params[:handle]),
                    kind => t("better_together.billing.credit.#{key}")
      end

      def grant(holder)
        currency = params[:currency].to_s.upcase
        cents = Currency.to_minor(params[:amount], currency)
        return unless cents&.positive? && Plan::SUPPORTED_CURRENCY_CODES.include?(currency)

        Credit::Grant.call(**grant_attributes(holder, currency, cents))
      rescue Credit::Refused
        nil
      end

      def grant_attributes(holder, currency, cents)
        { platform: billing_owner, holder:, amount_cents: cents, currency:, origin: 'steward_grant', actor: current_user.person,
          idempotency_key: "grant:#{current_user.person.id}:#{params[:token]}", expires_at:, note: params[:note].to_s.strip.presence }
      end

      # A whole number of days from now, or never.
      def expires_at
        days = params[:expires_in_days].to_s.strip
        days.match?(/\A\d{1,4}\z/) && days.to_i.positive? ? days.to_i.days.from_now : nil
      end
    end
  end
end
