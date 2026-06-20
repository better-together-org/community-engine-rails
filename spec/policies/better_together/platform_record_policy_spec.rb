# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PlatformRecordPolicy, type: :policy do
  let(:user)           { create(:better_together_user, :confirmed) }
  let(:host_platform)  { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, host: true) }
  let(:other_platform) { create(:better_together_platform, host: false) }

  describe 'helpers' do
    subject(:policy) { described_class.new(user, instance_double(BetterTogether::Agreement)) }

    describe '#current_platform' do
      it 'returns Current.platform when set' do
        Current.platform = other_platform
        expect(policy.current_platform).to eq(other_platform)
      ensure
        Current.platform = nil
      end

      it 'falls back to Current.host_platform when Current.platform is nil' do
        Current.platform = nil
        Current.host_platform = host_platform
        expect(policy.current_platform).to eq(host_platform)
      ensure
        Current.host_platform = nil
      end

      it 'returns nil when no platform context is set' do
        Current.platform = nil
        allow(BetterTogether::Platform).to receive(:find_by).with(host: true).and_return(nil)
        expect(policy.current_platform).to be_nil
      end
    end

    describe '#record_on_current_platform?' do
      subject(:policy) { described_class.new(user, record) }

      let(:record) { instance_double(BetterTogether::Agreement, platform_id: host_platform.id) }

      it 'returns true when record belongs to the current platform' do
        Current.platform = host_platform
        expect(policy.record_on_current_platform?).to be true
      ensure
        Current.platform = nil
      end

      it 'returns false when record belongs to a different platform' do
        Current.platform = other_platform
        expect(policy.record_on_current_platform?).to be false
      ensure
        Current.platform = nil
      end

      it 'returns false when no platform context is set' do
        _hp = host_platform # memoize before stub to avoid host uniqueness violation
        Current.platform = nil
        allow(BetterTogether::Platform).to receive(:find_by).with(host: true).and_return(nil)
        expect(policy.record_on_current_platform?).to be false
      end
    end
  end

  describe described_class::Scope do
    subject(:resolved) { described_class.new(user, scope).resolve }

    let!(:platform_a_record) { create(:better_together_agreement, platform: host_platform) }
    let!(:platform_b_record) { create(:better_together_agreement, platform: other_platform) }
    let(:scope)              { BetterTogether::Agreement.all }

    it 'returns records for the current platform when Current.platform is set' do
      Current.platform = host_platform
      expect(resolved).to include(platform_a_record)
      expect(resolved).not_to include(platform_b_record)
    ensure
      Current.platform = nil
    end

    it 'falls back to host_platform when Current.platform is nil' do
      Current.platform = nil
      Current.host_platform = host_platform
      expect(resolved).to include(platform_a_record)
      expect(resolved).not_to include(platform_b_record)
    ensure
      Current.host_platform = nil
    end

    it 'returns none when no platform context is set' do
      Current.platform = nil
      allow(BetterTogether::Platform).to receive(:find_by).with(host: true).and_return(nil)
      expect(resolved).to be_empty
    end
  end
end
