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
end
