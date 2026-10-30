# frozen_string_literal: true

require 'rails_helper'

# The methods core ships. They only describe themselves; core owns the payment state.
RSpec.describe 'Built-in payment method adapters' do # rubocop:disable RSpec/DescribeClass
  {
    cash: BetterTogether::Billing::Processors::Cash,
    cheque: BetterTogether::Billing::Processors::Cheque,
    etransfer: BetterTogether::Billing::Processors::ETransfer
  }.each do |name, klass|
    describe klass do
      let(:adapter) { klass.new }

      it_behaves_like 'a billing processor adapter'

      it 'is a manual, non-fee-collecting method that needs no webhook' do
        expect(adapter).to have_attributes(processor_name: name, settlement_kind: :manual, recurring_mode: :manual,
                                           fee_collectible?: false, webhook_event_types: [])
        expect(adapter.supports?(:offline_settlement)).to be(true)
      end

      it 'declares fields to fill in and checks nothing else about them' do
        expect(adapter.instruction_fields).to be_present
        expect(adapter.settings_errors({})).to be_a(Hash)
      end

      it 'processes a core-logged event as already decided, keeping the neutral outcome' do
        event = build_stubbed(:better_together_billing_event, outcome_kind: 'payment_confirmed')

        result = adapter.process_event(event:, context: nil)

        expect(result).to have_attributes(status: :processed, outcome_kind: :payment_confirmed)
      end

      it 'drops everything but identifiers and the outcome when sanitising a payload' do
        payload = { 'id' => 'e1', 'type' => "#{name}.payment_confirmed", 'outcome_kind' => 'payment_confirmed',
                    'buyer_email' => 'person@example.test' }

        expect(adapter.sanitize_payload(payload)).to eq(payload.except('buyer_email'))
      end

      it 'receives no webhooks' do
        expect { adapter.normalize_webhook({}) }.to raise_error(ArgumentError, /does not receive webhooks/)
      end

      it 'shows a buyer only the declared fields that have a value' do
        values = adapter.instruction_fields.to_h { |field| [field.name.to_s, "value for #{field.name}"] }.merge('stray' => 'x')

        shown = adapter.instructions_for(setting: values)

        expect(shown.keys).to eq(adapter.instruction_fields.map { |field| field.name.to_s })
        expect(shown).not_to have_key('stray')
        expect(adapter.instructions_for(setting: {})).to eq({})
      end
    end
  end

  describe BetterTogether::Billing::Processors::Cash do
    it 'needs to say where and when' do
      expect(described_class.new.settings_errors({ 'instructions' => ' ' })).to eq({ 'instructions' => :blank })
      expect(described_class.new.settings_errors({ 'instructions' => 'At the hall' })).to be_empty
    end

    it 'grants access when confirmed' do
      expect(described_class.new).to have_attributes(grant_on_options: %w[confirmed], default_grant_on: 'confirmed')
    end
  end

  describe BetterTogether::Billing::Processors::Cheque do
    it 'needs a payee and an address, and keeps nothing about a bank account' do
      adapter = described_class.new

      expect(adapter.settings_errors({})).to eq({ 'payee_name' => :blank, 'address' => :blank })
      expect(adapter.instruction_fields.map { |field| field.name.to_s }).not_to include(a_string_matching(/account|transit|routing|iban/))
    end

    it 'lets the seller wait for the cheque to clear, which is the default' do
      expect(described_class.new).to have_attributes(grant_on_options: %w[cleared received], default_grant_on: 'cleared')
    end
  end

  describe BetterTogether::Billing::Processors::ETransfer do
    let(:adapter) { described_class.new }

    it 'works only in Canada, in Canadian dollars' do
      expect(adapter).to have_attributes(supported_countries: %w[CA], supported_currencies: %w[CAD])
    end

    it 'needs an email or a phone number to send to' do
      expect(adapter.settings_errors({})).to eq({ 'recipient_email' => :recipient_missing })
      expect(adapter.settings_errors({ 'recipient_email' => 'seller@example.test' })).to be_empty
      expect(adapter.settings_errors({ 'recipient_phone' => '+1 709 555 0100' })).to be_empty
    end
  end
end
