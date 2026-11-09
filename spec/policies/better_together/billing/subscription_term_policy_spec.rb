# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::SubscriptionTermPolicy do
  include_context 'with subscription fixtures'
  include_context 'with billing switched on'

  let(:password) { 'SecureTest123!@#' }
  let(:term) { start_subscription }
  let(:stranger) { find_or_create_test_user("sub-policy-stranger-#{SecureRandom.hex(4)}@example.test", password) }

  around do |example|
    Current.platform = host_platform
    example.run
  ensure
    Current.platform = nil
  end

  it 'lets the payer see and manage their own subscription, and nobody else' do
    own = described_class.new(buyer_user, term)
    other = described_class.new(stranger, term)

    expect([own.show?, own.cancel?, own.resume?, own.accept_agreements?]).to all(be(true))
    expect([other.show?, other.cancel?, other.resume?, other.accept_agreements?]).to all(be(false))
    expect(described_class.new(nil, term).show?).to be(false)
  end

  it 'lets a steward see subscribers and manage them, but not through the payer\'s pages' do
    policy = described_class.new(steward_user, term)

    expect([policy.index?, policy.subscriber?, policy.waive?, policy.extend_grace?, policy.steward_cancel?, policy.move_to_current_price?])
      .to all(be(true))
    expect([policy.show?, policy.cancel?]).to all(be(false))
  end

  it 'keeps the steward screens from an ordinary member' do
    policy = described_class.new(stranger, term)

    expect([policy.index?, policy.subscriber?, policy.waive?, policy.extend_grace?, policy.steward_cancel?]).to all(be(false))
  end

  it 'never creates, edits or removes one through a screen' do
    policy = described_class.new(steward_user, term)

    expect([policy.create?, policy.update?, policy.destroy?]).to all(be(false))
  end
end
