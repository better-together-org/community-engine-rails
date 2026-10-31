# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Order do
  include_context 'with orders fixtures'

  it_behaves_like 'a platform-bound billing record' do
    def build_record(platform:) = build(:better_together_billing_order, platform:)
  end

  it 'is reached through its platform and cannot be exported as a seed' do
    order = create(:better_together_billing_order)

    expect(host_platform.billing_orders).to include(order)
    expect(order).not_to respond_to(:export_as_seed)
  end

  describe 'its reference' do
    it 'is generated, short and unique per platform' do
      first = create(:better_together_billing_order)
      second = create(:better_together_billing_order)

      expect(first.number).to match(/\ABT-[A-Z0-9]{8}\z/)
      expect(first.number).not_to eq(second.number)
    end

    it 'is unique within a platform at the database level' do
      first = create(:better_together_billing_order)
      duplicate = build(:better_together_billing_order, number: first.number)

      expect(duplicate).not_to be_valid
      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe 'validation' do
    it 'needs a buyer, a known purpose and status, and a supported currency' do
      expect(build(:better_together_billing_order, buyer: nil)).not_to be_valid
      expect(build(:better_together_billing_order, purpose: 'barter')).not_to be_valid
      expect(build(:better_together_billing_order, status: 'lost')).not_to be_valid
      expect(build(:better_together_billing_order, currency: 'XXX')).not_to be_valid
    end

    it 'takes its totals from its lines' do
      order = build(:better_together_billing_order)
      order.lines.build(platform_id: order.platform_id, purchasable: plan, description: 'A', quantity: 2, unit_amount_cents: 1500,
                        currency: 'USD')
      order.lines.build(platform_id: order.platform_id, purchasable: plan, description: 'B', quantity: 1, unit_amount_cents: 500,
                        currency: 'USD')
      order.save!

      expect(order).to have_attributes(subtotal_cents: 3500, total_cents: 3500)
    end

    it 'refuses a subject type that has not opted in' do
      order = build(:better_together_billing_order)
      order.assign_attributes(subject_type: 'Kernel', subject_id: SecureRandom.uuid)

      expect(order).not_to be_valid
    end

    it 'accepts an on-behalf-of owner only from the allow-list, on its platform' do
      community = create(:better_together_community)

      expect(build(:better_together_billing_order, on_behalf_of: community)).to be_valid
      other = build(:better_together_billing_order)
      other.assign_attributes(on_behalf_of_type: 'BetterTogether::Platform', on_behalf_of_id: host_platform.id)
      expect(other).not_to be_valid
      other_id = create(:better_together_platform).id
      community.define_singleton_method(:billing_bound_platform_id) { other_id }
      expect(build(:better_together_billing_order, on_behalf_of: community)).not_to be_valid
    end
  end

  describe 'status' do
    it 'moves only along the allowed paths' do
      order = create(:better_together_billing_order)

      expect(order.update(status: 'paid')).to be(false)
      expect(order.errors.details[:status]).to include(a_hash_including(error: :transition_not_allowed, from: 'draft', to: 'paid'))
      expect(order.update(status: 'awaiting_payment')).to be(true)
      expect(order.update(status: 'paid')).to be(true)
      expect(order.update(status: 'awaiting_payment')).to be(false)
    end

    it 'treats cancelled and refunded as final' do
      %w[cancelled refunded].each do |status|
        order = create(:better_together_billing_order)
        order.update_columns(status:) # rubocop:disable Rails/SkipsModelValidations

        expect(order).to be_final
        expect(order.update(status: 'paid')).to be(false)
      end
    end

    it 'lets a late payment pay an expired order' do
      order = create(:better_together_billing_order)
      order.update_columns(status: 'expired') # rubocop:disable Rails/SkipsModelValidations

      expect(order).to be_can_become('paid')
      expect(order).not_to be_can_become('draft')
    end

    it 'knows when it is waiting for payment and when its hold has run out' do
      order = create(:better_together_billing_order, :awaiting_payment)

      expect(order).to be_open
      expect(order).not_to be_hold_expired
      order.expires_at = 1.minute.ago
      expect(order).to be_hold_expired
      expect(described_class.unpaid).to include(order)
    end

    it 'finds the orders whose hold has run out' do
      lapsed = create(:better_together_billing_order, :awaiting_payment, expires_at: 1.hour.ago)
      create(:better_together_billing_order, :awaiting_payment)
      create(:better_together_billing_order, status: 'draft', expires_at: 1.hour.ago)

      expect(described_class.expired_holds).to contain_exactly(lapsed)
    end
  end

  describe 'money' do
    it 'adds up what was paid, still counting a payment that was later refunded' do
      order = create(:better_together_billing_order, :awaiting_payment, total_cents: 4500)
      create(:better_together_billing_payment, order:, status: 'succeeded', amount_cents: 3000, currency: 'USD')
      create(:better_together_billing_payment, order:, status: 'partially_refunded', amount_cents: 1000, currency: 'USD')
      create(:better_together_billing_payment, order:, status: 'pending', amount_cents: 500, currency: 'USD')

      expect(order.reload).to have_attributes(paid_cents: 4000, balance_cents: 500)
    end
  end

  describe 'who sells and who buys' do
    let(:community) { create(:better_together_community) }

    before { BetterTogether::Billing::Billable.model_names << 'BetterTogether::Community' }

    it 'can be sold by a seller, and found by buyer' do
      order = create(:better_together_billing_order, seller: community)

      expect(described_class.sold_by(community)).to contain_exactly(order)
      expect(described_class.sold_by_platform).not_to include(order)
      expect(described_class.bought_by(order.buyer)).to contain_exactly(order)
    end
  end

  it 'backs the composite foreign key of its children with the database' do
    order = create(:better_together_billing_order)
    other_platform = create(:better_together_platform)

    expect do
      described_class.connection.execute(<<~SQL.squish)
        INSERT INTO better_together_billing_order_lines
          (platform_id, order_id, purchasable_type, purchasable_id, description, quantity, unit_amount_cents, currency, lock_version, created_at, updated_at)
        VALUES ('#{other_platform.id}', '#{order.id}', 'BetterTogether::Billing::Plan', '#{SecureRandom.uuid}', 'X', 1, 1, 'USD', 0, now(), now())
      SQL
    end.to raise_error(ActiveRecord::InvalidForeignKey)
  end
end
