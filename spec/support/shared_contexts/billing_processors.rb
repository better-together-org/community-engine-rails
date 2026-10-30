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
