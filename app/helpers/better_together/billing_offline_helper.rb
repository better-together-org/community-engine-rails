# frozen_string_literal: true

module BetterTogether
  # View helpers for payments made outside the platform (cash, cheque, e-transfer).
  module BillingOfflineHelper
    OFFLINE_BADGE_CLASSES = {
      'awaiting' => 'bg-warning text-dark', 'claimed' => 'bg-info text-dark', 'received' => 'bg-info text-dark',
      'confirmed' => 'bg-success', 'cleared' => 'bg-success', 'bounced' => 'bg-danger', 'rejected' => 'bg-secondary',
      'expired' => 'bg-dark', 'cancelled' => 'bg-secondary'
    }.freeze

    def billing_offline_status_badge(offline)
      content_tag(:span, t("better_together.billing.offline_payments.status_#{offline.status}"),
                  class: "badge billing-offline-status-badge #{OFFLINE_BADGE_CLASSES.fetch(offline.status, 'bg-secondary')}",
                  id: dom_id(offline, :status_badge))
    end

    # What the buyer must understand before paying outside the platform: the keys for the notes that
    # apply to this method, in the order they are shown.
    def billing_offline_disclosure_keys(offline)
      common = %w[outside no_tracking seller_confirms hold]
      (common + [{ 'cash' => 'cash_in_person', 'cheque' => 'cheque_clearing', 'etransfer' => 'etransfer_canada' }[offline.processor]].compact)
        .map { |key| "better_together.billing.offline_payments.disclosure_#{key}" }
    end

    # The fields the seller filled in, with their labels, for this method; only the ones with a value.
    def billing_offline_instruction_rows(offline)
      adapter = BetterTogether::Billing.processor_adapter(offline.processor)
      return [] unless adapter

      adapter.instruction_fields.filter_map do |field|
        value = offline.instructions[field.name.to_s]
        [billing_instruction_field_label(offline.processor, field), value] if value.present?
      end
    end
  end
end
