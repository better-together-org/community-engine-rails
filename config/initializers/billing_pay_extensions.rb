# frozen_string_literal: true

# Extends Pay's models with Community Engine behaviour. Every behaviour lives in a
# namespaced concern under BetterTogether::Billing::PayExtensions; this block only
# includes them. to_prepare (not after_initialize) so the includes are re-applied
# whenever Pay's reloadable constants are reloaded; including a concern that is
# already present is a no-op.
Rails.application.config.to_prepare do
  [Pay::Customer, Pay::Merchant, Pay::PaymentMethod, Pay::Subscription, Pay::Charge].each do |model|
    model.include(BetterTogether::Billing::PayExtensions::PlatformScoping)
    model.include(BetterTogether::Billing::PayExtensions::EncryptedBillingData)
  end

  [Pay::Customer, Pay::Subscription, Pay::Charge].each do |model|
    model.include(BetterTogether::Billing::PayExtensions::LocalProcessor)
  end

  # What a subscription gives follows the subscription, however it changes.
  Pay::Subscription.include(BetterTogether::Billing::PayExtensions::EntitlementSync)

  # Paid plans set the quota limits: the allowance provider the quota framework asks (see Quotas::Allowances).
  BetterTogether::Quotas::Allowances.register('billing_entitlements', BetterTogether::Billing::Entitlements::QuotaAllowances)

  Pay::Webhook.include(BetterTogether::Billing::PayExtensions::EncryptedWebhookEvent)
  Pay::ApplicationJob.include(BetterTogether::Billing::PayExtensions::BillingQueueRouting)
end
