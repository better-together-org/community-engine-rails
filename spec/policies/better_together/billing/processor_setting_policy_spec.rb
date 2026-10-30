# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::ProcessorSettingPolicy do
  include_context 'with clean billing processors'
  include_context 'with builtin billing processors'
  include_context 'with billing switched on'

  let!(:host_platform) { configure_host_platform }
  let(:other_platform) { create(:better_together_platform) }
  let(:setting) { host_platform.billing_processor_settings.build(processor: 'cash') }
  let(:steward) { find_or_create_test_user("setting-policy-steward-#{SecureRandom.hex(4)}@example.test", 'SecureTest123!@#', :platform_manager) }
  let(:member) { find_or_create_test_user("setting-policy-member-#{SecureRandom.hex(4)}@example.test", 'SecureTest123!@#') }

  around do |example|
    Current.platform = host_platform
    example.run
  ensure
    Current.platform = nil
  end

  %i[index? show? edit? update?].each do |action|
    describe "##{action}" do
      it 'is allowed for a steward before any method is on, so the first one can be turned on' do
        expect(BetterTogether::Billing.enabled?(host_platform)).to be(false)
        expect(described_class.new(steward, setting).public_send(action)).to be(true)
      end

      it 'is refused to a member and a visitor' do
        expect(described_class.new(member, setting).public_send(action)).to be(false)
        expect(described_class.new(nil, setting).public_send(action)).to be(false)
      end

      it 'is refused while billing is not switched on for the host' do
        allow(BetterTogether::Billing::Configuration).to receive(:requested?).and_return(false)

        expect(described_class.new(steward, setting).public_send(action)).to be(false)
      end

      it 'asks about the record\'s own platform' do
        foreign = other_platform.billing_processor_settings.build(processor: 'cash')

        expect(described_class.new(steward, foreign).public_send(action)).to be(false)
      end
    end
  end

  it 'never allows destroying a setting' do
    expect(described_class.new(steward, setting).destroy?).to be(false)
  end

  describe 'a setting a community sells through' do
    let(:community) { create(:better_together_community) }

    it 'is not managed through the platform by a platform steward' do
      BetterTogether::Billing::Billable.model_names << 'BetterTogether::Community'
      seller_setting = host_platform.billing_processor_settings.build(processor: 'cash', seller: community)

      expect(described_class.new(steward, seller_setting).edit?).to be(false)
    end
  end

  describe BetterTogether::Billing::ProcessorSettingPolicy::Scope do
    it 'returns the platform\'s own settings to a steward, and nothing else' do
      mine = host_platform.billing_processor_settings.create!(processor: 'cash')
      other_platform.billing_processor_settings.create!(processor: 'cash')

      expect(described_class.new(steward, BetterTogether::Billing::ProcessorSetting).resolve).to contain_exactly(mine)
      expect(described_class.new(member, BetterTogether::Billing::ProcessorSetting).resolve).to be_empty
      expect(described_class.new(nil, BetterTogether::Billing::ProcessorSetting).resolve).to be_empty
    end
  end
end
