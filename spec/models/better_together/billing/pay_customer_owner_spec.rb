# frozen_string_literal: true

require 'rails_helper'

# A person can be a customer of several platforms. Pay's own owner API is platform-blind, so these examples
# pin down that ours is not: it requires a platform and never reads or changes another platform's customers.
RSpec.describe BetterTogether::Billing::PayCustomerOwner do
  let(:person) { create(:better_together_person) }
  let(:platform_a) { create(:better_together_platform) }
  let(:platform_b) { create(:better_together_platform) }

  def add(processor, platform, **) = person.add_payment_processor(processor, platform:, allow_fake: true, **)

  it 'is on the person, and the person is registered as able to own billing records' do
    expect(BetterTogether::Person.ancestors).to include(described_class, BetterTogether::Billing::Billable)
    expect(BetterTogether::Billing::Billable.model_names).to include('BetterTogether::Person')
  end

  it 'does not let Pay look an owner up from a client reference, which would create a customer with no platform' do
    expect(Pay::Stripe.model_names).not_to include('BetterTogether::Person')
  end

  describe 'a person who pays on two platforms' do
    it 'has one customer on each, and each is the default on its own platform' do
      a = person.set_payment_processor(:fake_processor, platform: platform_a, allow_fake: true)
      b = person.set_payment_processor(:fake_processor, platform: platform_b, allow_fake: true)

      expect(a).not_to eq(b)
      expect([a.platform_id, b.platform_id]).to eq([platform_a.id, platform_b.id])
      expect([a.reload.default, b.reload.default]).to eq([true, true])
      expect(person.payment_processor_for(platform_a)).to eq(a)
      expect(person.payment_processor_for(platform_b)).to eq(b)
    end

    it 'does not clear or rewrite the other platform\'s customer when one is made the default again' do
      a = person.set_payment_processor(:fake_processor, platform: platform_a, allow_fake: true, processor_id: 'cus_a')
      person.set_payment_processor(:fake_processor, platform: platform_b, allow_fake: true)

      person.set_payment_processor(:fake_processor, platform: platform_b, allow_fake: true)

      expect(a.reload).to have_attributes(default: true, processor_id: 'cus_a', platform_id: platform_a.id)
    end

    it 'finds the same customer again on the same platform, rather than making another' do
      first = add(:fake_processor, platform_a)

      expect(add(:fake_processor, platform_a)).to eq(first)
      expect(person.pay_customers.count).to eq(1)
    end

    it 'adds a customer without changing which one is the default' do
      default = person.set_payment_processor(:fake_processor, platform: platform_a, allow_fake: true)

      add(:fake_processor, platform_a, stripe_account: 'acct_x')

      expect(person.payment_processor_for(platform_a)).to eq(default)
    end
  end

  describe 'without a platform' do
    it 'refuses to add or set a customer, instead of guessing from the request or failing inside a job' do
      Current.platform = platform_a

      expect { person.add_payment_processor(:fake_processor, allow_fake: true) }.to raise_error(described_class::PlatformRequired)
      expect { person.set_payment_processor(:fake_processor, allow_fake: true) }.to raise_error(described_class::PlatformRequired)
      expect { person.payment_processor_for(nil) }.to raise_error(described_class::PlatformRequired)
    ensure
      Current.platform = nil
    end

    it 'refuses the unscoped payment_processor, which would be nondeterministic with customers on several platforms' do
      add(:fake_processor, platform_a)
      add(:fake_processor, platform_b)

      expect { person.payment_processor }.to raise_error(described_class::UnscopedProcessor, /payment_processor_for/)
    end
  end

  describe 'which processors it will create' do
    it 'refuses Pay\'s fake processor unless asked, and any name that is not a known processor' do
      expect { person.add_payment_processor(:fake_processor, platform: platform_a) }.to raise_error(Pay::Error, /not allowed/)
      expect { person.add_payment_processor('Kernel', platform: platform_a) }.to raise_error(Pay::Error, /not allowed/)
      expect { person.add_payment_processor('../../x', platform: platform_a, allow_fake: true) }.to raise_error(Pay::Error)
    end
  end

  it 'reads its name and email for Pay, binds no platform, and does not sync an email change through Pay' do
    expect(person.pay_customer_name).to eq(person.name)
    expect(person).to respond_to(:email)
    expect(person.billing_bound_platform_id).to be_nil
    expect(person.pay_should_sync_customer?).to be(false)
  end
end
