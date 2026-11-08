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

    # The processors this platform can create plans with, as select options. Only online
    # processors: methods outside a vendor are chosen separately (see
    # #billing_offline_method_choices).
    def billing_processor_choices
      BetterTogether::Billing::Configuration.processors_for(billing_owner)
                                            .map(&:to_s)
                                            .reject { |name| BetterTogether::Billing::Plan.offline_method?(name) }
                                            .map { |name| [name, name] }
    end

    # Installed methods that do not go through a vendor (cash, cheque, e-transfer, store
    # credit), as [label, name] pairs for the "also accept" check boxes.
    def billing_offline_method_choices
      BetterTogether::Billing.processor_names.map(&:to_s)
                             .select { |name| BetterTogether::Billing::Plan.offline_method?(name) }
                             .map { |name| [billing_payment_method_label(name), name] }
    end

    # On, off, or not set up yet; the page lists every installed method.
    def billing_processor_setting_badge(setting)
      state = if setting.nil? then 'not_set_up'
              elsif setting.enabled? then 'enabled'
              else 'disabled'
              end
      classes = { 'enabled' => 'bg-success', 'disabled' => 'bg-secondary', 'not_set_up' => 'bg-light text-dark border' }
      content_tag(:span, t("better_together.billing.processor_settings.status_#{state}"),
                  class: "badge billing-processor-setting-status-badge #{classes.fetch(state)}")
    end

    # Where a method works, in words: anywhere, or only in some countries and currencies.
    def billing_method_availability(adapter)
      countries = adapter.supported_countries
      return t('better_together.billing.processor_settings.available_anywhere') if countries.blank?

      t('better_together.billing.processor_settings.available_only_in', countries: countries.to_sentence,
                                                                        currencies: Array(adapter.supported_currencies).to_sentence)
    end

    def billing_instruction_field_label(method_name, field)
      t("better_together.billing.processor_settings.fields.#{method_name}.#{field.name}", default: field.name.to_s.humanize)
    end

    def billing_payment_method_label(name)
      t("better_together.billing.plans.payment_method_names.#{name}", default: name.to_s.humanize)
    end
  end
end
