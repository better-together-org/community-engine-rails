# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::FederationHub::ActivityFeedService do
  describe '.call' do
    let(:person) { create(:better_together_person) }

    it 'includes activities the person performed on their own federatable content' do
      post = create(:better_together_post, creator: person)
      BetterTogether::Activity.create!(trackable: post, key: 'post.create', owner: person)

      result = described_class.call(person:)

      expect(result.map(&:key)).to include('post.create')
    end

    it 'excludes connection activity when include_admin_feed is false' do
      connection = create(:better_together_platform_connection, :active)
      connection.mark_sync_succeeded!(item_count: 1)

      result = described_class.call(person:, include_admin_feed: false)

      expect(result.map(&:trackable_type)).not_to include('BetterTogether::PlatformConnection')
    end

    it 'includes connection activity when include_admin_feed is true' do
      connection = create(:better_together_platform_connection, :active)
      connection.mark_sync_succeeded!(item_count: 1)

      result = described_class.call(person:, include_admin_feed: true)

      expect(result.map(&:trackable_type)).to include('BetterTogether::PlatformConnection')
    end

    it "does not include another person's content activity" do
      other = create(:better_together_person)
      other_post = create(:better_together_post, creator: other)
      BetterTogether::Activity.create!(trackable: other_post, key: 'post.create', owner: other)

      result = described_class.call(person:)

      expect(result.map(&:trackable)).not_to include(other_post)
    end

    it 'filters by content_type' do
      post = create(:better_together_post, creator: person)
      page = create(:better_together_page, creator: person)
      BetterTogether::Activity.create!(trackable: post, key: 'post.create', owner: person)
      BetterTogether::Activity.create!(trackable: page, key: 'page.create', owner: person)

      result = described_class.call(person:, filters: { content_type: 'post' })

      expect(result.map(&:trackable)).to contain_exactly(post)
    end

    it 'filters connection activity by direction' do
      host_platform = BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, :host)
      remote_platform = create(:better_together_platform)
      outgoing = create(:better_together_platform_connection, :active, source_platform: host_platform,
                                                                       target_platform: remote_platform)
      incoming = create(:better_together_platform_connection, :active, source_platform: remote_platform,
                                                                       target_platform: host_platform)
      outgoing.mark_sync_succeeded!(item_count: 1)
      incoming.mark_sync_succeeded!(item_count: 1)

      result = described_class.call(person: nil, include_admin_feed: true, filters: { direction: 'outgoing' })

      expect(result.map(&:trackable)).to contain_exactly(outgoing)
    end

    it 'paginates results' do
      post = create(:better_together_post, creator: person)
      6.times { |i| BetterTogether::Activity.create!(trackable: post, key: "post.update.#{i}", owner: person) }

      result = described_class.call(person:, per_page: 5, page: 1)

      expect(result.length).to eq(5)
      expect(result.total_count).to eq(6)
    end
  end
end
