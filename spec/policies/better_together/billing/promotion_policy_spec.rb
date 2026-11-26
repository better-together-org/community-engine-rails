# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::PromotionPolicy do
  include_context 'with orders fixtures'
  include_context 'with billing switched on'

  let(:password) { 'SecureTest123!@#' }
  let(:steward) { find_or_create_test_user("promo-policy-steward-#{SecureRandom.hex(4)}@example.test", password, :platform_manager) }
  let(:member) { find_or_create_test_user("promo-policy-member-#{SecureRandom.hex(4)}@example.test", password) }
  let(:promotion) { host_platform.billing_promotions.build(name: 'P', amount_cents: 1, currency: 'USD') }

  around do |example|
    Current.platform = host_platform
    example.run
  ensure
    Current.platform = nil
  end

  it 'lets a steward list, make and switch promotions' do
    policy = described_class.new(steward, promotion)

    expect([policy.index?, policy.new?, policy.create?, policy.activate?, policy.deactivate?]).to all(be(true))
  end

  it 'keeps all of that from a member and a visitor' do
    [member, nil].each do |user|
      policy = described_class.new(user, promotion)

      expect([policy.index?, policy.new?, policy.create?, policy.activate?, policy.deactivate?]).to all(be(false))
    end
  end

  it 'never shows or edits one, because a code cannot be read back' do
    policy = described_class.new(steward, promotion)

    expect([policy.show?, policy.update?, policy.destroy?]).to all(be(false))
  end
end
