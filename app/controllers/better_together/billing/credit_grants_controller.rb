# frozen_string_literal: true

module BetterTogether
  module Billing
    # A steward gives a person store credit. Repeating the form (a double click) gives it once: the form
    # carries a token that becomes the grant's idempotency key. A steward cannot give themselves credit.
    class CreditGrantsController < ApplicationController
      include OwnerScoped
      include PersonLookup

      after_action :verify_authorized

      def create
        authorize BetterTogether::Billing::CreditAccount, :grant?
        holder = find_platform_person(params[:person_id])
        lot = holder && grant(holder)
        return back(:alert, lot_refusal) unless lot

        redirect_to billing_credit_account_path(lot.account, locale: I18n.locale), notice: t('better_together.billing.credit.granted')
      end

      private

      def back(kind, message)
        redirect_to billing_credit_accounts_path(locale: I18n.locale, person_id: params[:person_id]), kind => message
      end

      # The same message for a non-member and an unknown id, so a refusal never says whether the person exists.
      def lot_refusal
        return t('better_together.billing.credit.grant_refused') unless over_maximum?

        t('better_together.billing.credit.grant_too_large', maximum: helpers.billing_amount(maximum_minor, currency))
      end

      def over_maximum? = amount_minor.to_i > maximum_minor

      def currency = params[:currency].to_s.upcase

      def amount_minor = Currency.to_minor(params[:amount], currency)

      def maximum_minor = Configuration.max_credit_grant_minor(currency)

      def grant(holder)
        return if params[:token].to_s.strip.blank?

        cents = amount_minor
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
