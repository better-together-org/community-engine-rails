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

  Pay::Webhook.include(BetterTogether::Billing::PayExtensions::EncryptedWebhookEvent)
  Pay::ApplicationJob.include(BetterTogether::Billing::PayExtensions::BillingQueueRouting)
end
