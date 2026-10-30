# frozen_string_literal: true

Pay.setup do |config|
  config.automount_routes = false
  config.application_name = ENV.fetch('PAY_APPLICATION_NAME', 'Community Engine')
  config.send_emails = false

  # Pay's records inherit from this abstract class instead of the host's
  # ApplicationRecord; see BetterTogether::Billing::PayRecord for why.
  config.model_parent_class = 'BetterTogether::Billing::PayRecord'

  # Host identity has no built-in default; see BetterTogether::Billing::Configuration.
  config.business_name = ENV['PAY_BUSINESS_NAME'].presence
  config.business_address = ENV['PAY_BUSINESS_ADDRESS'].presence
  config.support_email = ENV['PAY_SUPPORT_EMAIL'].presence
end

Rails.application.config.after_initialize do
  BetterTogether::Billing::Configuration.log_missing!
end
