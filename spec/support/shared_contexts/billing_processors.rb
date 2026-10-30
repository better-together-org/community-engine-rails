# frozen_string_literal: true

# Isolates the :billing_processor adapter registry per example.
RSpec.shared_context 'with clean billing processors' do
  around do |example|
    BetterTogether.clear_adapters!(BetterTogether::Billing::ADAPTER_GROUP)
    example.run
  ensure
    BetterTogether.clear_adapters!(BetterTogether::Billing::ADAPTER_GROUP)
  end
end

# Billing is off unless the host switches it on (BT_BILLING_ENABLED). Request specs for
# the billing screens need it on; the identity variables come from
# spec/support/better_together/billing_configuration.rb.
RSpec.shared_context 'with billing switched on' do
  around do |example|
    previous = ENV.fetch('BT_BILLING_ENABLED', nil)
    ENV['BT_BILLING_ENABLED'] = 'true'
    example.run
  ensure
    previous.nil? ? ENV.delete('BT_BILLING_ENABLED') : ENV['BT_BILLING_ENABLED'] = previous
  end
end

# The methods core ships (cash, cheque, e-transfer). 'with clean billing processors' empties
# the registry, so a spec that needs them registers them after it.
RSpec.shared_context 'with builtin billing processors' do
  before { BetterTogether::Billing.register_builtin_processors! }
end
