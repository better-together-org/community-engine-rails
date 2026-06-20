# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Activity do
  describe 'platform capture' do
    let(:platform) { create(:better_together_platform, host: false) }
    let(:post)     { create(:post, platform: platform) }

    it 'inherits platform from the trackable when Current.platform is nil' do
      BetterTogether::Current.platform = nil
      activity = described_class.new(trackable: post, key: 'post.create', owner: nil)
      activity.run_callbacks(:create) { false } # trigger before_create without persisting
      expect(activity.platform).to eq(platform)
    end

    it 'uses Current.platform when set' do
      BetterTogether::Current.platform = platform
      activity = described_class.new(trackable: nil, key: 'platform.updated', owner: nil)
      activity.run_callbacks(:create) { false }
      expect(activity.platform).to eq(platform)
    ensure
      BetterTogether::Current.platform = nil
    end

    it 'falls back to host platform when neither Current.platform nor trackable.platform is set' do
      host_platform = BetterTogether::Platform.find_by(host: true) ||
                      create(:better_together_platform, host: true)
      BetterTogether::Current.platform = nil
      activity = described_class.new(trackable: nil, key: 'test.action', owner: nil)
      activity.run_callbacks(:create) { false }
      expect(activity.platform_id).to eq(host_platform.id)
    end
  end

  it_behaves_like 'platform scoped', factory: :public_activity_activity
end
