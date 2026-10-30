# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::PlanPolicy do
  include_context 'with clean billing processors'
  include_context 'with billing switched on'

  let!(:host_platform) { configure_host_platform }
  let(:other_platform) { create(:better_together_platform) }
  let(:plan) do
    BetterTogether::Billing.register_processor(:fake, -> { BetterTogether::Billing::FakeAdapter.new(capabilities: %i[plan_sync]) })
    create(:better_together_billing_plan)
  end
  let(:steward) { find_or_create_test_user("plan-policy-steward-#{SecureRandom.hex(4)}@example.test", 'SecureTest123!@#', :platform_manager) }
  let(:member) { find_or_create_test_user("plan-policy-member-#{SecureRandom.hex(4)}@example.test", 'SecureTest123!@#') }

  around do |example|
    Current.platform = host_platform
    example.run
  ensure
    Current.platform = nil
  end

  %i[index? show? new? create? edit? update? sync? snapshot? lookup?].each do |action|
    describe "##{action}" do
      it 'is allowed for a steward of the platform' do
        expect(described_class.new(steward, plan).public_send(action)).to be(true)
      end

      it 'is refused to a signed-in member' do
        expect(described_class.new(member, plan).public_send(action)).to be(false)
      end

      it 'is refused to a visitor' do
        expect(described_class.new(nil, plan).public_send(action)).to be(false)
      end

      it 'is refused while billing is off' do
        plan
        allow(BetterTogether::Billing::Configuration).to receive(:requested?).and_return(false)

        expect(described_class.new(steward, plan).public_send(action)).to be(false)
      end
    end
  end

  it 'never allows destroying a plan' do
    expect(described_class.new(steward, plan).destroy?).to be(false)
  end

  it 'asks about the plan\'s own platform, not the current one' do
    foreign = build(:better_together_billing_plan, platform: other_platform)

    expect(described_class.new(steward, foreign).show?).to be(false)
  end

  describe '#manage_billing?' do
    it 'refuses an owner that cannot be named, rather than defaulting to the host' do
      expect(described_class.new(steward, BetterTogether::Billing::Plan).manage_billing?(nil)).to be(false)
    end

    it 'is the same question for any platform' do
      expect(described_class.new(steward, plan).manage_billing?(other_platform)).to be(false)
    end
  end

  describe BetterTogether::Billing::PlanPolicy::Scope do
    it 'returns the current platform\'s plans to a steward' do
      plan

      expect(described_class.new(steward, BetterTogether::Billing::Plan).resolve).to contain_exactly(plan)
    end

    it 'never returns another platform\'s plans' do
      plan
      foreign = build(:better_together_billing_plan, platform: other_platform).tap { |record| record.save!(validate: false) }

      expect(described_class.new(steward, BetterTogether::Billing::Plan).resolve).not_to include(foreign)
    end

    it 'returns nothing to a member, a visitor, or when there is no current platform' do
      plan
      Current.platform = nil

      expect(described_class.new(steward, BetterTogether::Billing::Plan).resolve).to be_empty
      Current.platform = host_platform
      expect(described_class.new(member, BetterTogether::Billing::Plan).resolve).to be_empty
      expect(described_class.new(nil, BetterTogether::Billing::Plan).resolve).to be_empty
    end
  end
end
