# frozen_string_literal: true

module BetterTogether
  # View helpers shared by the billing pages.
  module BillingHelper
    SYNC_BADGE_CLASSES = { 'pending' => 'bg-warning text-dark', 'synced' => 'bg-success', 'failed' => 'bg-danger' }.freeze

    def billing_amount(amount_minor, currency)
      number_to_currency(
        BetterTogether::Billing::Currency.to_major(amount_minor, currency),
        unit: BetterTogether::Billing::Currency.unit(currency),
        precision: BetterTogether::Billing::Currency.exponent(currency)
      )
    end

    def billing_interval_label(interval)
      t("better_together.billing.plans.interval_#{interval}", default: interval.to_s.humanize)
    end

    # Options for a processor-backed select, in the shape the SlimSelect Stimulus controller
    # reads. The list is fetched live from the platform's processor as the person types; the
    # processor is read from the form's processor field, and `scope_from` narrows the list by
    # another field (prices of the chosen product).
    def billing_lookup_options(kind:, scope_from: {}, preserve_selection: false)
      {
        ajax: { url: billing_processor_options_path(locale: I18n.locale), params: { kind: },
                paramsFrom: { processor: '#billing_plan_processor' }.merge(scope_from),
                errorText: t('better_together.billing.plans.lookup_unavailable'),
                errorHeader: BetterTogether::Billing::ProcessorOptionsController::UNAVAILABLE_HEADER },
        preserveSelection: preserve_selection,
        requiredMessage: t('better_together.billing.plans.select_required'),
        settings: { searchPlaceholder: t('better_together.billing.plans.lookup_search'), searchHighlight: true,
                    closeOnSelect: true, allowDeselect: true, openPosition: 'down' }
      }.to_json
    end

    def billing_sync_badge(plan)
      content_tag(:span, t("better_together.billing.plans.sync_status_#{plan.sync_status}"),
                  class: "badge billing-plan-sync-status-badge #{SYNC_BADGE_CLASSES.fetch(plan.sync_status, 'bg-secondary')}",
                  id: dom_id(plan, :sync_status_badge))
    end

    def billing_sync_error(plan)
      return if plan.sync_error.blank?

      t("better_together.billing.plans.sync_errors.#{plan.sync_error}", default: t('better_together.billing.plans.sync_errors.processor_error'))
    end

    # The names of the fields this plan can no longer change, for the explanatory note.
    def billing_locked_field_names(plan)
      fields = BetterTogether::Billing::Plan::PRICE_FIELDS + [:processor] + BetterTogether::Billing::Plan::DESCRIPTIVE_FIELDS
      fields.select { |field| plan.locked_field?(field) }
            .map { |field| t("better_together.billing.plans.field_#{field}") }
    end

    # The processors this platform can create plans with, as select options.
    def billing_processor_choices
      BetterTogether::Billing::Configuration.processors_for(billing_owner).map { |name| [name.to_s, name.to_s] }
    end
  end
end
