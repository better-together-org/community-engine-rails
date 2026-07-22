# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::InboundEmailResolutionService do
  def address(value)
    Mail::Address.new(value)
  end

  def create_tenant(community:, domain:)
    platform = create(:better_together_platform, community:, host_url: "https://#{domain}")
    platform.platform_domains.find_or_create_by!(hostname: domain) do |platform_domain|
      platform_domain.primary = true
      platform_domain.active = true
    end

    platform
  end

  def issue_token(recipient:, platform:, repliable: nil)
    BetterTogether::InboundEmailReplyToken.issue!(
      recipient:,
      repliable: repliable || create(:better_together_post),
      notification_type: 'comment_added',
      platform:
    )
  end

  it 'returns a tenant-scoped community resolution for mapped domains' do
    community = create(:better_together_community, name: 'Tenant Resolution Community')
    platform = create_tenant(community:, domain: 'tenant-resolution.example.test')

    resolution = described_class.new(address("community+#{community.slug}@tenant-resolution.example.test")).resolve

    expect(resolution.route_kind).to eq('community')
    expect(resolution.platform).to eq(platform)
    expect(resolution.target).to eq(community)
  end

  it 'returns unresolved for community aliases on the wrong tenant domain' do
    first_community = create(:better_together_community, name: 'First Tenant')
    platform = create_tenant(community: first_community, domain: 'tenant-one.example.test')
    second_community = create(:better_together_community, name: 'Second Tenant')
    create_tenant(community: second_community, domain: 'tenant-two.example.test')

    resolution = described_class.new(address("community+#{second_community.slug}@tenant-one.example.test")).resolve

    expect(resolution.route_kind).to eq('unresolved')
    expect(resolution.platform).to eq(platform)
    expect(resolution.target).to be_nil
  end

  describe 'reply+ resolution' do
    it 'resolves a reply token when the sender matches the recipient' do
      community = create(:better_together_community, name: 'Reply Tenant')
      platform = create_tenant(community:, domain: 'tenant-reply.example.test')
      person = create(:better_together_person)
      token = issue_token(recipient: person, platform:)

      resolution = described_class.new(
        address(token.reply_address('tenant-reply.example.test')),
        sender: address(person.email)
      ).resolve

      expect(resolution.route_kind).to eq('reply')
      expect(resolution.target).to eq(token)
    end

    it 'rejects a reply token when the sender does not match the recipient' do
      community = create(:better_together_community, name: 'Reply Tenant Guard')
      platform = create_tenant(community:, domain: 'tenant-reply-guard.example.test')
      person = create(:better_together_person)
      token = issue_token(recipient: person, platform:)

      resolution = described_class.new(
        address(token.reply_address('tenant-reply-guard.example.test')),
        sender: address('someone-else@example.test')
      ).resolve

      expect(resolution.route_kind).to eq('unresolved')
      expect(resolution.target).to be_nil
    end

    it 'rejects an already-consumed reply token' do
      community = create(:better_together_community, name: 'Reply Tenant Consumed')
      platform = create_tenant(community:, domain: 'tenant-reply-consumed.example.test')
      person = create(:better_together_person)
      token = issue_token(recipient: person, platform:)
      token.consume!

      resolution = described_class.new(
        address(token.reply_address('tenant-reply-consumed.example.test')),
        sender: address(person.email)
      ).resolve

      expect(resolution.route_kind).to eq('unresolved')
      expect(resolution.target).to be_nil
    end

    it 'rejects an unknown token value' do
      community = create(:better_together_community, name: 'Reply Tenant Unknown')
      create_tenant(community:, domain: 'tenant-reply-unknown.example.test')

      resolution = described_class.new(
        address('reply+not-a-real-token@tenant-reply-unknown.example.test'),
        sender: address('anyone@example.test')
      ).resolve

      expect(resolution.route_kind).to eq('unresolved')
      expect(resolution.target).to be_nil
    end

    it 'rejects a reply token issued for a different tenant platform' do
      community_a = create(:better_together_community, name: 'Reply Tenant A')
      platform_a = create_tenant(community: community_a, domain: 'tenant-reply-a.example.test')
      community_b = create(:better_together_community, name: 'Reply Tenant B')
      create_tenant(community: community_b, domain: 'tenant-reply-b.example.test')
      person = create(:better_together_person)
      token = issue_token(recipient: person, platform: platform_a)

      resolution = described_class.new(
        address(token.reply_address('tenant-reply-b.example.test')),
        sender: address(person.email)
      ).resolve

      expect(resolution.route_kind).to eq('unresolved')
      expect(resolution.target).to be_nil
    end
  end
end
