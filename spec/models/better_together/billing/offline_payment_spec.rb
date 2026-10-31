# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::OfflinePayment do
  include_context 'with offline payment fixtures'

  let(:order) { place_offline('cash') }
  let(:offline) { offline_for(order) }

  describe 'associations' do
    it 'belongs to an order and a payment, and the payment has one' do
      expect(offline.order).to eq(order)
      expect(offline.payment.offline_payment).to eq(offline)
      expect(order.offline_payments).to contain_exactly(offline)
    end
  end

  describe 'platform' do
    it 'takes the order\'s platform and cannot differ from it' do
      expect(offline.platform_id).to eq(order.platform_id)

      offline.platform_id = create(:better_together_platform).id
      expect(offline).not_to be_valid
    end

    it 'is tied to its order and payment by composite foreign keys, so the database refuses a different platform' do
      second = create(:better_together_billing_payment, order:, processor: 'cash', amount_cents: 100, idempotency_key: 'second')
      row = offline.attributes.merge('id' => SecureRandom.uuid, 'payment_id' => second.id, 'platform_id' => create(:better_together_platform).id)
      columns = %w[id platform_id order_id payment_id processor status grant_on created_at updated_at]
      values = columns.map { |column| described_class.connection.quote(row[column] || Time.current) }
      sql = "INSERT INTO better_together_billing_offline_payments (#{columns.join(', ')}) VALUES (#{values.join(', ')})"

      expect { described_class.connection.execute(sql) }.to raise_error(ActiveRecord::InvalidForeignKey)
    end
  end

  describe 'validations' do
    it 'only knows the statuses of the state machine' do
      offline.status = 'paid'

      expect(offline).not_to be_valid
    end

    it 'only moves along the state machine' do
      offline.update!(status: 'confirmed')

      offline.status = 'awaiting'
      expect(offline).not_to be_valid
      expect(offline.errors[:status]).to be_present
    end

    it 'lets an expired payment still be confirmed, and a received cheque clear or bounce, but nothing leave a final state' do
      expect(described_class::TRANSITIONS['expired']).to include('confirmed', 'received')
      expect(described_class::TRANSITIONS['received']).to contain_exactly('cleared', 'bounced')
      %w[confirmed cleared bounced rejected cancelled].each { |status| expect(described_class::TRANSITIONS[status]).to be_empty }
    end

    it 'only exists for a method outside a vendor' do
      offline.processor = 'fake'

      expect(offline).not_to be_valid
    end

    it 'never has a platform fee, since the platform never sees the money' do
      offline.platform_fee_cents = 50

      expect(offline).not_to be_valid
    end

    it 'limits the length of what people type' do
      offline.buyer_reference = 'x' * 201
      offline.rejection_reason = 'x' * 201

      expect(offline).not_to be_valid
      expect(offline.errors.attribute_names).to include(:buyer_reference, :rejection_reason)
    end

    it 'is for a payment of its own order' do
      other_order = place_offline('cash', buyer: other_buyer)
      offline.payment = offline_for(other_order).payment

      expect(offline).not_to be_valid
    end

    it 'cannot change what the buyer was told, or how it was paid, once opened' do
      offline.update!(instructions_snapshot: { 'instructions' => 'elsewhere' }, processor: 'cheque', grant_on: 'received')

      expect(offline.reload.instructions).to eq('instructions' => 'Hand it to Alex at the hall')
      expect(offline).to have_attributes(processor: 'cash', grant_on: 'confirmed')
    end
  end

  describe 'encryption' do
    it 'keeps the references and the instructions encrypted at rest' do
      offline.update!(buyer_reference: 'buyer secret', seller_reference: 'seller secret')
      raw = described_class.connection.select_one(
        'SELECT buyer_reference, seller_reference, instructions_snapshot ' \
        "FROM better_together_billing_offline_payments WHERE id = '#{offline.id}'"
      ).values.join

      expect(raw).not_to include('secret', 'Alex')
    end
  end

  describe 'queries' do
    it 'lists what is waiting, what lapsed, and what still needs the seller' do
      claimed = offline_for(place_offline('cash', buyer: other_buyer)).tap { |record| record.update!(status: 'claimed') }
      cheque = offline_for(place_offline('cheque')).tap { |record| record.update!(status: 'received') }
      done = offline_for(place_offline('cash', buyer: steward)).tap { |record| record.update!(status: 'confirmed') }
      lapsed = offline.tap { |record| record.update!(expires_at: 1.hour.ago) }
      old = offline_for(place_offline('cash', buyer: other_steward)).tap { |record| record.update!(status: 'expired', expired_at: 31.days.ago) }

      expect(described_class.waiting).to contain_exactly(claimed, lapsed)
      expect(described_class.lapsed).to contain_exactly(lapsed)
      expect(described_class.needing_attention).to contain_exactly(claimed, cheque, lapsed)
      expect(described_class.needing_attention).not_to include(done, old)
    end
  end

  describe 'helpers' do
    it 'knows when the seller has said the money arrived, and which status that is' do
      expect(offline).not_to be_money_received
      expect(offline.receipt_status).to eq('confirmed')
      expect(offline_for(place_offline('cheque')).receipt_status).to eq('received')
      %w[received confirmed cleared].each { |status| expect(described_class.new(status:)).to be_money_received }
    end

    it 'grants on receipt unless it is a cheque set to grant on clearing' do
      expect(offline.grants_on_receipt?).to be(true)
      expect(offline_for(place_offline('cheque')).grants_on_receipt?).to be(false)
    end

    it 'knows whether the buyer said they sent it' do
      expect(offline).not_to be_claimed_by_buyer

      offline.update!(claimed_at: Time.current)
      expect(offline).to be_claimed_by_buyer
    end
  end

  it 'cannot be deleted with its payment still pointing at it' do
    offline

    expect(offline.payment.destroy).to be(false)
    expect(described_class.exists?(offline.id)).to be(true)
  end
end
