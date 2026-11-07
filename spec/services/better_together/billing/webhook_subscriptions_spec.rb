# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::WebhookSubscriptions do
  include_context 'with clean billing processors'

  let(:delegator) { instance_double(Pay::Webhooks::Delegator, subscribe: nil) }

  before do
    allow(Pay::Webhooks).to receive(:delegator).and_return(delegator)
    described_class.instance_variable_set(:@subscribed, nil)
  end

  it 'subscribes each registered processor event type exactly once' do
    BetterTogether::Billing.register_processor(:fake, -> { BetterTogether::Billing::FakeAdapter.new })

    2.times { described_class.subscribe_all! }

    expect(delegator).to have_received(:subscribe).with('fake.invoice.paid', an_instance_of(BetterTogether::Billing::WebhookDispatcher)).once
  end

  it 'subscribes nothing when no processor is registered' do
    described_class.subscribe_all!

    expect(delegator).not_to have_received(:subscribe)
  end

  describe 'a processor that cannot be set up' do
    before do
      allow(BetterTogether).to receive(:report_error)
      allow(Rails.logger).to receive(:error)
      BetterTogether::Billing.register_processor(:broken, -> { raise 'cannot build' })
      BetterTogether::Billing.register_processor(:fake, -> { BetterTogether::Billing::FakeAdapter.new })
    end

    it 'does not stop the application booting, and still subscribes the others' do
      expect { described_class.subscribe_all! }.not_to raise_error

      expect(delegator).to have_received(:subscribe).with('fake.invoice.paid', anything).once
    end

    it 'logs and reports the failure' do
      described_class.subscribe_all!

      expect(Rails.logger).to have_received(:error).with(/could not subscribe broken webhooks/)
      expect(BetterTogether).to have_received(:report_error).with(an_instance_of(RuntimeError), context: { processor: :broken })
    end
  end
end
