# frozen_string_literal: true

# Contract every Billing::ProcessorAdapter must satisfy; the Stripe gem runs it too.
RSpec.shared_examples 'a billing processor adapter' do
  it 'inherits the core contract at the supported version' do
    expect { BetterTogether::Billing::ProcessorAdapter.verify!(adapter) }.not_to raise_error
  end

  it 'names its processor and only advertises known capabilities' do
    expect(adapter.processor_name).to be_a(Symbol)
    expect(adapter.capabilities - BetterTogether::Billing::ProcessorAdapter::CAPABILITIES).to be_empty
  end

  it 'implements the event pipeline methods' do
    base = BetterTogether::Billing::ProcessorAdapter
    %i[normalize_webhook process_event sanitize_payload processor_name].each do |name|
      expect(adapter.method(name).owner).not_to eq(base), "#{name} not overridden"
    end
  end

  it 'returns a sanitized copy of a payload' do
    payload = { 'id' => 'evt_1', 'type' => 'x', 'customer_email' => 'person@example.test' }

    expect(adapter.sanitize_payload(payload)).not_to include('customer_email')
  end

  it 'overrides and accepts the documented keywords for each advertised capability' do
    BetterTogether::Billing::ProcessorAdapter::CAPABILITY_METHODS.slice(*adapter.capabilities).each_value do |methods|
      methods.each do |name, keywords|
        params = adapter.method(name).parameters
        expect(adapter.method(name).owner).not_to eq(BetterTogether::Billing::ProcessorAdapter), "#{name} not overridden"
        expect(params.any? { |type, _| type == :keyrest } || keywords.all? { |k| params.include?([:keyreq, k]) || params.include?([:key, k]) })
          .to be(true), "#{name} must accept #{keywords.inspect}"
      end
    end
  end
end
