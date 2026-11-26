# frozen_string_literal: true

# The engine ships no billing identity defaults; give the suite a neutral one.
# Specs that exercise the unconfigured path stub Billing::Configuration.ready?.
{
  'PAY_BUSINESS_NAME' => 'Example Co-op',
  'PAY_BUSINESS_ADDRESS' => '1 Main St, Example City',
  'PAY_SUPPORT_EMAIL' => 'support@example.org'
}.each { |key, value| ENV[key] ||= value }
