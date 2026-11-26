# frozen_string_literal: true

module BetterTogether
  # View helpers for the payment methods page of the billing screens.
  module BillingPaymentMethodsHelper
    # The row's state for a method. A method settled here has its own switch (a setting). A vendor
    # processor is on for the platform when the deployment gives it a context, and that is all
    # the page can say about it.
    def billing_method_status_badge(name, setting, platform)
      return billing_processor_setting_badge(setting) if BetterTogether::Billing.local_method?(name)

      on = BetterTogether::Billing::Configuration.context_for(platform, name).present?
      key = on ? 'managed_on' : 'managed_off'
      content_tag(:span, t("better_together.billing.processor_settings.status_#{key}"),
                  class: "badge billing-processor-setting-status-badge #{on ? 'bg-success' : 'bg-secondary'}")
    end
  end
end
