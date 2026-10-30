# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Payment do
  include_context 'with orders fixtures'
  include_context 'with builtin billing processors'

  let(:order) { create(:better_together_billing_order, :awaiting_payment, total_cents: 4500) }

  def payment(**attrs) = build(:better_together_billing_payment, order:, **attrs)

  describe 'its platform' do
    it 'is its order\'s, never the request\'s' do
      Current.platform = create(:better_together_platform)
      built = host_platform.billing_orders.create!(buyer: create(:better_together_person), purpose: 'one_time', currency: 'USD')
                           .payments.build(processor: 'fake', amount_cents: 100, currency: 'USD', idempotency_key: 'k')

      expect(built).to be_valid
      expect(built.platform_id).to eq(host_platform.id)
    ensure
      Current.platform = nil
    end

    it 'has a NOT NULL column and is found through its platform' do
      expect(described_class.columns_hash.fetch('platform_id').null).to be(false)
      saved = create(:better_together_billing_payment, order:)

      expect(described_class.for_platform(host_platform)).to include(saved)
      expect(described_class.for_platform(create(:better_together_platform))).not_to include(saved)
    end
  end

  it 'is valid for an installed method, a positive amount and a unique key' do
    expect(payment).to be_valid
  end

  it 'can be made by a method outside a vendor too' do
    expect(payment(processor: 'cash')).to be_valid
  end

  it 'needs an installed method' do
    bad = payment(processor: 'bitcoin')

    expect(bad).not_to be_valid
    expect(bad.errors.details[:processor]).to include(a_hash_including(error: :not_installed))
  end

  it 'needs a positive whole amount in its order\'s currency' do
    expect(payment(amount_cents: 0)).not_to be_valid
    expect(payment(amount_cents: 12.5)).not_to be_valid
    expect(payment(currency: 'CAD')).not_to be_valid
  end

  it 'has an idempotency key that is unique per platform' do
    create(:better_together_billing_payment, order:, idempotency_key: 'same-key')

    expect(payment(idempotency_key: 'same-key')).not_to be_valid
    expect { payment(idempotency_key: 'same-key').save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it 'moves only along the allowed paths' do
    pending_payment = create(:better_together_billing_payment, order:)

    expect(pending_payment.update(status: 'refunded')).to be(false)
    expect(pending_payment.update(status: 'succeeded')).to be(true)
    expect(pending_payment.update(status: 'pending')).to be(false)
    expect(pending_payment.update(status: 'partially_refunded')).to be(true)
  end

  it 'lets a failed payment be tried again, but not a cancelled one' do
    failed = create(:better_together_billing_payment, order:, status: 'failed')
    cancelled = create(:better_together_billing_payment, order:, status: 'cancelled')

    expect(failed.update(status: 'pending')).to be(true)
    expect(cancelled.update(status: 'pending')).to be(false)
  end

  it 'works out what can still be refunded' do
    paid = create(:better_together_billing_payment, order:, status: 'succeeded', amount_cents: 4500)
    create(:better_together_billing_refund, payment: paid, amount_cents: 1000, status: 'recorded')
    create(:better_together_billing_refund, payment: paid, amount_cents: 500, status: 'failed', idempotency_key: 'f1')

    expect(paid.reload).to have_attributes(refunded_cents: 1000, refundable_cents: 3500)
    expect(create(:better_together_billing_payment, order:, status: 'pending').refundable_cents).to eq(0)
  end

  it 'cannot belong to an order of another platform, at the database level' do
    other = create(:better_together_platform)

    expect { payment(platform_id: other.id).save!(validate: false) }.to raise_error(ActiveRecord::InvalidForeignKey)
  end
end
