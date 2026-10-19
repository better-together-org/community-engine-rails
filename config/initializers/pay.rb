# frozen_string_literal: true

Pay.setup do |config|
  config.automount_routes = false
  config.application_name = ENV.fetch('PAY_APPLICATION_NAME', 'Community Engine')
  config.send_emails = false

  # Host identity has no built-in default; see BetterTogether::Billing::Configuration.
  config.business_name = ENV['PAY_BUSINESS_NAME'].presence
  config.business_address = ENV['PAY_BUSINESS_ADDRESS'].presence
  config.support_email = ENV['PAY_SUPPORT_EMAIL'].presence
end

Rails.application.config.after_initialize do
  BetterTogether::Billing::Configuration.log_missing!
end

ActiveSupport.on_load(:pay) do
  dispatcher = BetterTogether::Billing::StripeEventDispatcher.new

  BetterTogether::Billing::StripeEventDispatcher::EVENT_TYPES.each do |event_name|
    Pay::Webhooks.delegator.subscribe(event_name, dispatcher)
  end

  Pay::Subscription.has_one :billing_subscription_record,
                            class_name: 'BetterTogether::Billing::Subscription',
                            foreign_key: :pay_subscription_id,
                            dependent: :destroy,
                            inverse_of: :pay_subscription
end
