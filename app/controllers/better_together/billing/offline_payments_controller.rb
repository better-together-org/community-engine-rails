# frozen_string_literal: true

module BetterTogether
  module Billing
    # What the seller has to do about payments made outside the platform: say the money arrived,
    # say it did not, and for a cheque say it cleared or bounced.
    #
    # Confirming never needs the buyer to have said anything first. The payment is reached through
    # the platform and only among what the platform itself sells, so another platform's payment is a
    # 404 whatever id is sent.
    class OfflinePaymentsController < ApplicationController
      include OwnerScoped

      Transition = OfflinePayments::Transition

      before_action :set_offline_payment, only: %i[receive reject clear bounce]
      after_action :verify_authorized

      def index
        authorize BetterTogether::Billing::OfflinePayment
        @offline_payments = policy_scope(BetterTogether::Billing::OfflinePayment).needing_attention.includes(order: :buyer)
                                                                                 .sort_by do |offline|
          [offline.claimed_by_buyer? ? 0 : 1,
           offline.created_at]
        end
      end

      def receive
        act { Transition.receive(@offline_payment, by: current_person, reference: reference, received_on: received_on) }
      end

      def reject
        act { Transition.reject(@offline_payment, by: current_person, reason: params[:reason].to_s.strip.first(OfflinePayment::REASON_LIMIT)) }
      end

      def clear
        act { Transition.clear(@offline_payment, by: current_person) }
      end

      def bounce
        act { Transition.bounce(@offline_payment, by: current_person) }
      end

      private

      def set_offline_payment
        @offline_payment = policy_scope(BetterTogether::Billing::OfflinePayment).find(params[:id])
      end

      def current_person = current_user.person

      def reference = params[:seller_reference].to_s.strip.first(OfflinePayment::REFERENCE_LIMIT).presence

      def received_on
        Date.iso8601(params[:received_on].to_s)
      rescue Date::Error
        nil
      end

      def act
        authorize @offline_payment
        yield
        redirect_to destination, notice: t("better_together.billing.offline_payments.done.#{action_name}")
      rescue Transition::Refused => e
        redirect_to destination, alert: t("better_together.billing.offline_payments.refused.#{e.class.name.demodulize.underscore}")
      rescue ActiveRecord::RecordInvalid
        redirect_to destination, alert: t('better_together.billing.offline_payments.refused.invalid')
      end

      def destination
        return billing_sale_path(@offline_payment.order, locale: I18n.locale) if params[:from] == 'sale'

        billing_offline_payments_path(locale: I18n.locale)
      end
    end
  end
end
