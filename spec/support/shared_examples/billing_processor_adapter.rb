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

  # An adapter may name its keywords or take a named catch-all (`**args`). An
  # anonymous `**` does not count: it accepts anything without ever reading it,
  # which is how the base class stubs are written.
  it 'overrides and accepts the documented keywords, including context:, for each advertised capability' do
    BetterTogether::Billing::ProcessorAdapter::CAPABILITY_METHODS.slice(*adapter.capabilities).each_value do |methods|
      methods.each do |name, keywords|
        method = adapter.method(name)
        params = method.parameters
        named_catch_all = params.any? { |type, param| type == :keyrest && param != :** }
        explicit = keywords.all? { |keyword| params.include?([:keyreq, keyword]) || params.include?([:key, keyword]) }

        expect(method.owner).not_to eq(BetterTogether::Billing::ProcessorAdapter), "#{name} not overridden"
        expect(named_catch_all || explicit)
          .to be(true), "#{name} must accept #{keywords.inspect} (an anonymous ** does not count)"
      end
    end
  end

  describe 'processor-backed fields' do
    it 'declares only known rules, for plan fields' do
      rules = adapter.field_rules(:plan)

      expect(rules).to be_a(Hash)
      expect(rules.values - BetterTogether::Billing::ProcessorAdapter::FIELD_RULES).to be_empty
      expect(rules.keys - BetterTogether::Billing::Plan::PRICE_FIELDS - BetterTogether::Billing::Plan::DESCRIPTIVE_FIELDS -
             %i[processor processor_product_id processor_price_id]).to be_empty
    end

    it 'names the lookup kinds it serves when it advertises lookups' do
      next unless adapter.supports?(:lookups)

      expect(adapter.lookup_kinds).to be_present
      expect(adapter.lookup_kinds).to all(be_a(Symbol))
    end

    it 'offers fallback lists of the right shape, or nil for core\'s own' do
      expect(adapter.supported_currencies).to be_nil.or all(be_a(String))
      expect(adapter.supported_intervals).to be_nil.or all(be_a(String))
    end
  end

  describe 'settlement' do
    let(:contract) { BetterTogether::Billing::ProcessorAdapter }

    it 'declares a known settlement kind and recurring mode' do
      expect(contract::SETTLEMENT_KINDS).to include(adapter.settlement_kind)
      expect(contract::RECURRING_MODES).to include(adapter.recurring_mode)
    end

    it 'reports supported countries as nil or ISO alpha-2 codes' do
      countries = adapter.supported_countries

      expect(countries).to be_nil.or all(match(/\A[A-Z]{2}\z/))
    end

    it 'advertises offline_settlement exactly when it is a manual method, and then declares instruction fields' do
      expect(adapter.supports?(:offline_settlement)).to eq(adapter.settlement_kind == :manual)
      next unless adapter.supports?(:offline_settlement)

      expect(adapter.instruction_fields).to all(be_a(BetterTogether::Billing::InstructionField))
      expect(adapter.fee_collectible?).to be(false)
    end
  end
end
