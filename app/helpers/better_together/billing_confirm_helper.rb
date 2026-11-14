# frozen_string_literal: true

module BetterTogether
  # The questions asked before a steward moves money, as the text and Stimulus values the forms carry.
  module BillingConfirmHelper
    CONFIRM_CONTROLLER = 'better-together--billing-confirm'

    # The question asked before a steward marks an offline payment received, naming the order, buyer and amount.
    def billing_receive_confirm(offline)
      order = offline.order
      key = offline.cheque? ? 'receive_cheque_confirm' : 'receive_confirm'
      t("better_together.billing.offline_payments.#{key}", number: order.number, buyer: order.buyer.name,
                                                           amount: billing_amount(order.total_cents, order.currency))
    end

    # Form data for a refund: it asks first, naming the amount typed (or the full remaining amount when none is).
    def billing_refund_confirm_data(order, payment, key)
      scope = "better_together.billing.sales.#{key}"
      args = { number: order.number, buyer: order.buyer.name }
      { turbo_confirm: t(scope, amount: billing_amount(payment.refundable_cents, payment.currency), **args),
        controller: CONFIRM_CONTROLLER, "#{CONFIRM_CONTROLLER}-currency-value" => payment.currency,
        "#{CONFIRM_CONTROLLER}-template-value" => t(scope, amount: '{amount}', **args),
        "#{CONFIRM_CONTROLLER}-fallback-value" => t(scope, amount: billing_amount(payment.refundable_cents, payment.currency), **args) }
    end

    # Form data for granting store credit: it asks first, naming the person and the amount typed.
    def billing_grant_confirm_data(holder)
      { turbo_confirm: t('better_together.billing.credit.grant_confirm_blank', person: holder.name),
        controller: CONFIRM_CONTROLLER,
        "#{CONFIRM_CONTROLLER}-template-value" => t('better_together.billing.credit.grant_confirm', person: holder.name, amount: '{amount}'),
        "#{CONFIRM_CONTROLLER}-fallback-value" => t('better_together.billing.credit.grant_confirm_blank', person: holder.name) }
    end
  end
end
