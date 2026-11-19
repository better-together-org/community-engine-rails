# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::CreditAccountPolicy do
  include_context 'with orders fixtures'
  include_context 'with billing switched on'

  let(:password) { 'SecureTest123!@#' }
  let(:steward) { find_or_create_test_user("credit-policy-steward-#{SecureRandom.hex(4)}@example.test", password, :platform_manager) }
  let(:member) { find_or_create_test_user("credit-policy-member-#{SecureRandom.hex(4)}@example.test", password) }
  let(:account) { host_platform.billing_credit_accounts.create!(holder: member.person, currency: 'USD') }

  around do |example|
    Current.platform = host_platform
    example.run
  ensure
    Current.platform = nil
  end

  it 'lets any signed-in person look at their own credit page, and nobody else' do
    expect(described_class.new(member, account).own?).to be(true)
    expect(described_class.new(nil, account).own?).to be(false)
  end

  it 'lets a steward see accounts, look people up and give credit' do
    policy = described_class.new(steward, account)

    expect([policy.index?, policy.show?, policy.grant?]).to all(be(true))
  end

  it 'keeps those from an ordinary member, including the holder, who sees their credit on their own page instead' do
    policy = described_class.new(member, account)

    expect([policy.index?, policy.show?, policy.grant?]).to all(be(false))
  end

  it 'never lets an account be created, changed or removed through a screen' do
    policy = described_class.new(steward, account)

    expect([policy.create?, policy.update?, policy.destroy?]).to all(be(false))
  end
end
