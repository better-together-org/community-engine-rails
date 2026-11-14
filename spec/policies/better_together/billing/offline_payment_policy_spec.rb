# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::OfflinePaymentPolicy do
  include_context 'with offline payment fixtures'
  include_context 'with billing switched on'

  let(:order) { place_offline('cash') }
  let(:offline) { offline_for(order) }
  let(:other_platform) { create(:better_together_platform) }

  around do |example|
    Current.platform = host_platform
    example.run
  ensure
    Current.platform = nil
  end

  it 'lets a steward of the platform work the queue and decide each payment' do
    policy = described_class.new(steward_user, offline)

    expect([policy.index?, policy.receive?, policy.reject?, policy.clear?, policy.bounce?]).to all(be(true))
  end

  it 'turns away the buyer, another member and a visitor' do
    [buyer_user, other_buyer_user, nil].each do |user|
      policy = described_class.new(user, offline)

      expect([policy.index?, policy.receive?, policy.reject?, policy.clear?, policy.bounce?]).to all(be(false))
    end
  end

  it 'never lets anyone create, change or destroy one through the screens' do
    policy = described_class.new(steward_user, offline)

    expect([policy.show?, policy.create?, policy.update?, policy.destroy?]).to all(be(false))
  end

  it 'is not for something a community or person sold' do
    BetterTogether::Billing::Order.connection.execute(
      "UPDATE better_together_billing_orders SET seller_type = 'BetterTogether::Community', " \
      "seller_id = '#{SecureRandom.uuid}' WHERE id = '#{order.id}'"
    )

    expect(described_class.new(steward_user, offline.reload).receive?).to be(false)
  end

  describe 'scope' do
    it 'is what the platform itself sells, for a steward' do
      offline
      foreign_order = create(:better_together_billing_order, :awaiting_payment, platform: other_platform, total_cents: 100)
      foreign_payment = create(:better_together_billing_payment, order: foreign_order, platform_id: other_platform.id, processor: 'cash',
                                                                 amount_cents: 100)
      foreign = foreign_order.offline_payments.create!(platform_id: other_platform.id, payment: foreign_payment, processor: 'cash')

      scope = described_class::Scope.new(steward_user, BetterTogether::Billing::OfflinePayment).resolve

      expect(scope).to contain_exactly(offline)
      expect(scope).not_to include(foreign)
    end

    it 'is empty for a buyer, a visitor, and when there is no platform' do
      offline

      expect(described_class::Scope.new(buyer_user, BetterTogether::Billing::OfflinePayment).resolve).to be_empty
      expect(described_class::Scope.new(nil, BetterTogether::Billing::OfflinePayment).resolve).to be_empty
      Current.platform = nil
      expect(described_class::Scope.new(steward_user, BetterTogether::Billing::OfflinePayment).resolve).to be_empty
    end
  end

  describe 'the buyer\'s part, in the order policy' do
    it 'lets only the buyer say they sent it' do
      expect(BetterTogether::Billing::OrderPolicy.new(buyer_user, order).claim?).to be(true)
      expect(BetterTogether::Billing::OrderPolicy.new(other_buyer_user, order).claim?).to be(false)
      expect(BetterTogether::Billing::OrderPolicy.new(steward_user, order).claim?).to be(false)
      expect(BetterTogether::Billing::OrderPolicy.new(nil, order).claim?).to be(false)
    end

    it 'lets only a steward record a refund or a sale in person' do
      expect(BetterTogether::Billing::OrderPolicy.new(steward_user, order).refund?).to be(true)
      expect(BetterTogether::Billing::OrderPolicy.new(buyer_user, order).refund?).to be(false)
      expect(BetterTogether::Billing::OrderPolicy.new(steward_user, BetterTogether::Billing::Order).walk_up?).to be(true)
      expect(BetterTogether::Billing::OrderPolicy.new(buyer_user, BetterTogether::Billing::Order).walk_up?).to be(false)
    end
  end
end
