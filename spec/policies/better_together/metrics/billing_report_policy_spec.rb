# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Metrics::BillingReportPolicy, type: :policy do
  include_context 'with clean billing processors'
  include_context 'with builtin billing processors'
  include_context 'with billing switched on'

  let(:host_platform) { BetterTogether::Platform.find_by(host: true) }
  let(:manager) { find_or_create_test_user("bp-manager-#{SecureRandom.hex(4)}@example.test", 'SecureTest123!@#', :platform_manager) }
  let(:member) { find_or_create_test_user("bp-member-#{SecureRandom.hex(4)}@example.test", 'SecureTest123!@#') }
  let(:record) { %i[metrics billing_report] }
  let(:own) { BetterTogether::Metrics::BillingReport.create!(platform: host_platform, filters: { 'owner' => 'all' }) }
  let(:foreign) { BetterTogether::Metrics::BillingReport.create!(platform: create(:better_together_platform), filters: { 'owner' => 'all' }) }

  before { allow(Current).to receive_messages(platform: host_platform, host_platform:) }

  it 'lets a platform manager do everything on this platform', :aggregate_failures do
    expect(described_class.new(manager, record).index?).to be(true)
    expect(described_class.new(manager, record).create?).to be(true)
    expect(described_class.new(manager, own).download?).to be(true)
    expect(described_class.new(manager, own).destroy?).to be(true)
  end

  it 'denies guests and members', :aggregate_failures do
    [nil, member].each do |user|
      expect(described_class.new(user, record).index?).to be(false)
      expect(described_class.new(user, record).create?).to be(false)
      expect(described_class.new(user, own).download?).to be(false)
    end
  end

  it 'never reaches a report of another platform', :aggregate_failures do
    expect(described_class.new(manager, foreign).download?).to be(false)
    expect(described_class.new(manager, foreign).destroy?).to be(false)
  end

  it 'is closed when billing is not configured' do
    allow(BetterTogether::Billing).to receive(:configurable?).and_return(false)

    expect(described_class.new(manager, record).index?).to be(false)
  end
end
