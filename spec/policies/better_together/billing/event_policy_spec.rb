# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::EventPolicy do
  include_context 'with clean billing processors'
  include_context 'with builtin billing processors'
  include_context 'with billing switched on'

  let!(:host_platform) { configure_host_platform }
  let(:other_platform) { create(:better_together_platform) }
  let(:steward) { find_or_create_test_user("event-policy-steward-#{SecureRandom.hex(4)}@example.test", 'SecureTest123!@#', :platform_manager) }
  let(:member) { find_or_create_test_user("event-policy-member-#{SecureRandom.hex(4)}@example.test", 'SecureTest123!@#') }
  let(:dead) { create(:better_together_billing_event, processing_status: 'dead_lettered') }
  let(:done) { create(:better_together_billing_event, processing_status: 'processed') }

  around do |example|
    Current.platform = host_platform
    example.run
  ensure
    Current.platform = nil
  end

  %i[index? show?].each do |action|
    it "allows #{action} for a host platform manager" do
      expect(described_class.new(steward, dead).public_send(action)).to be(true)
    end

    it "refuses #{action} to a member and a visitor" do
      expect(described_class.new(member, dead).public_send(action)).to be(false)
      expect(described_class.new(nil, dead).public_send(action)).to be(false)
    end

    it "refuses #{action} while billing is not configurable" do
      allow(BetterTogether::Billing::Configuration).to receive(:requested?).and_return(false)

      expect(described_class.new(steward, dead).public_send(action)).to be(false)
    end
  end

  it 'refuses a manager of a platform that is not the host' do
    steward
    Current.platform = other_platform
    foreign = create(:better_together_billing_event, platform: other_platform)

    expect(described_class.new(steward, foreign).index?).to be(false)
    expect(described_class.new(steward, foreign).show?).to be(false)
  end

  describe '#replay?' do
    it 'is allowed to a host operator, leaving the replay service to say whether the event can run again' do
      expect(described_class.new(steward, dead).replay?).to be(true)
      expect(described_class.new(steward, done).replay?).to be(true)
    end

    it 'is refused to a member and a visitor' do
      expect(described_class.new(member, dead).replay?).to be(false)
      expect(described_class.new(nil, dead).replay?).to be(false)
    end
  end

  it 'never allows changing or removing an event' do
    policy = described_class.new(steward, dead)

    expect([policy.create?, policy.update?, policy.destroy?]).to all(be(false))
  end

  describe 'Scope' do
    it 'resolves the host platform events for a host manager' do
      dead
      elsewhere = create(:better_together_billing_event, platform: other_platform)

      resolved = described_class::Scope.new(steward, BetterTogether::Billing::Event).resolve

      expect(resolved).to include(dead)
      expect(resolved).not_to include(elsewhere)
    end

    it 'resolves nothing for a member, a visitor or a platform that is not the host' do
      dead
      steward
      expect(described_class::Scope.new(member, BetterTogether::Billing::Event).resolve).to be_empty
      expect(described_class::Scope.new(nil, BetterTogether::Billing::Event).resolve).to be_empty

      Current.platform = other_platform
      expect(described_class::Scope.new(steward, BetterTogether::Billing::Event).resolve).to be_empty
    end
  end
end
