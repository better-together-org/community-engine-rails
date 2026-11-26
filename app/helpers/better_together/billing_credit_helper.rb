# frozen_string_literal: true

module BetterTogether
  # View helpers for store credit and promotion codes.
  module BillingCreditHelper
    # "+$5.00" for money in, "-$5.00" for money out.
    def billing_signed_amount(amount_minor, currency)
      sign = amount_minor.negative? ? '-' : '+'
      "#{sign}#{billing_amount(amount_minor.abs, currency)}"
    end

    # When a lot of credit expires, or that it does not.
    def billing_credit_expiry(lot)
      lot.expires_at ? l(lot.expires_at.to_date, format: :long) : t('better_together.billing.credit.never_expires')
    end

    # What a lot of credit may pay for; any kind of purchase when it names none.
    def billing_credit_purposes(lot)
      return t('better_together.billing.credit.any_purpose') if lot.purposes.empty?

      lot.purposes.map { |purpose| t("better_together.billing.processor_settings.purpose_#{purpose}") }.to_sentence
    end

    # "3 of 10" used, or just "3" for a promotion with no cap.
    def billing_promotion_usage(promotion)
      return promotion.redemptions_count.to_s unless promotion.max_redemptions

      t('better_together.billing.promotions.usage_of', used: promotion.redemptions_count, max: promotion.max_redemptions)
    end

    # When a promotion can be used, from and until, or that it always can.
    def billing_promotion_window(promotion)
      return t('better_together.billing.promotions.always_open') unless promotion.starts_at || promotion.ends_at

      from = promotion.starts_at ? l(promotion.starts_at.to_date, format: :long) : '…'
      to = promotion.ends_at ? l(promotion.ends_at.to_date, format: :long) : '…'
      "#{from} – #{to}"
    end

    def billing_promotion_status_badge(promotion)
      key, css = if !promotion.active? then %w[off bg-secondary]
                 elsif promotion.exhausted? then %w[used_up bg-dark]
                 elsif promotion.ended? then %w[ended bg-dark]
                 elsif !promotion.started? then %w[scheduled bg-info text-dark]
                 else %w[on bg-success]
                 end
      tag.span(t("better_together.billing.promotions.status_#{key}"), class: "badge #{css} promotion-status-badge")
    end
  end
end
