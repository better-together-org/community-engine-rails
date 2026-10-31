# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::OrderPolicy do
  include_context 'with orders fixtures'
  include_context 'with billing switched on'

  let(:other_platform) { create(:better_together_platform) }
  let(:steward) { find_or_create_test_user("order-policy-steward-#{SecureRandom.hex(4)}@example.test", 'SecureTest123!@#', :platform_manager) }
  let(:member) { find_or_create_test_user("order-policy-member-#{SecureRandom.hex(4)}@example.test", 'SecureTest123!@#') }
  let(:stranger) { find_or_create_test_user("order-policy-stranger-#{SecureRandom.hex(4)}@example.test", 'SecureTest123!@#') }
  let(:order) { place_order(buyer: member.person) }

  around do |example|
    Current.platform = host_platform
    example.run
  ensure
    Current.platform = nil
  end

  it 'lets a buyer see their own orders and nobody else\'s' do
    expect(described_class.new(member, order).show?).to be(true)
    expect(described_class.new(stranger, order).show?).to be(false)
    expect(described_class.new(nil, order).show?).to be(false)
  end

  it 'does not let a steward see an order through the buyer\'s page' do
    expect(described_class.new(steward, order).show?).to be(false)
  end

  it 'lets any signed-in person list their own orders, and no visitor' do
    expect(described_class.new(member, BetterTogether::Billing::Order).index?).to be(true)
    expect(described_class.new(nil, BetterTogether::Billing::Order).index?).to be(false)
  end

  it 'lets any signed-in person start a checkout, and no visitor' do
    expect(described_class.new(member, BetterTogether::Billing::Order).checkout?).to be(true)
    expect(described_class.new(nil, BetterTogether::Billing::Order).checkout?).to be(false)
  end

  it 'never lets anyone create, change or destroy an order through the screens' do
    policy = described_class.new(steward, order)

    expect([policy.new?, policy.create?, policy.update?, policy.destroy?]).to all(be(false))
  end

  describe 'sales' do
    it 'are for a steward of the platform that sells the order' do
      expect(described_class.new(steward, order).sale?).to be(true)
      expect(described_class.new(steward, BetterTogether::Billing::Order).sales?).to be(true)
      expect(described_class.new(member, order).sale?).to be(false)
      expect(described_class.new(nil, order).sale?).to be(false)
    end

    it 'do not include an order another platform sold' do
      foreign = create(:better_together_billing_order, platform: other_platform)

      expect(described_class.new(steward, foreign).sale?).to be(false)
    end

    it 'do not include an order a community sold' do
      BetterTogether::Billing::Billable.model_names << 'BetterTogether::Community'
      community = create(:better_together_community)
      seller_order = create(:better_together_billing_order, seller: community)

      expect(described_class.new(steward, seller_order).sale?).to be(false)
    end

    it 'are refused while billing is off' do
      allow(BetterTogether::Billing::Configuration).to receive(:requested?).and_return(false)

      expect(described_class.new(steward, order).sale?).to be(false)
    end
  end

  describe BetterTogether::Billing::OrderPolicy::Scope do
    it 'returns a buyer\'s own orders on this platform only' do
      mine = place_order(buyer: member.person)
      place_order(buyer: stranger.person)
      create(:better_together_billing_order, platform: other_platform, buyer: member.person)

      expect(described_class.new(member, BetterTogether::Billing::Order).resolve).to contain_exactly(mine)
    end

    it 'returns nothing to a visitor or without a platform' do
      place_order(buyer: member.person)

      expect(described_class.new(nil, BetterTogether::Billing::Order).resolve).to be_empty
      Current.platform = nil
      expect(described_class.new(member, BetterTogether::Billing::Order).resolve).to be_empty
    end
  end
end
