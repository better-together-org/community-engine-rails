# frozen_string_literal: true

Pay.setup do |config|
  config.automount_routes = false
  config.business_name = ENV.fetch('PAY_BUSINESS_NAME', 'Better Together')
  config.business_address = ENV.fetch('PAY_BUSINESS_ADDRESS', "St. John's, NL, Canada")
  config.application_name = ENV.fetch('PAY_APPLICATION_NAME', 'Community Engine')
  config.support_email = ENV.fetch('PAY_SUPPORT_EMAIL', 'support@btsdev.ca')
  config.send_emails = false
end

ActiveSupport.on_load(:pay) do
  dispatcher = BetterTogether::Billing::StripeEventDispatcher.new

  BetterTogether::Billing::StripeEventDispatcher::EVENT_TYPES.each do |event_name|
    Pay::Webhooks.delegator.subscribe(event_name, dispatcher)
  end
end
