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
end
