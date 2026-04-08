# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::InboundEmailRoutingService do
  def build_inbound_email(raw_source)
    ActionMailbox::InboundEmail.create_and_extract_message_id!(raw_source)
  end

  def create_tenant(community:, domain:)
    create(:better_together_platform, community:, host_url: "https://#{domain}")
  end

  def raw_mail(to:, from: 'sender@example.test', subject: 'Test subject', body: 'Plain body')
    <<~MAIL
      From: Sender Example <#{from}>
      To: #{to}
      Subject: #{subject}
      Message-ID: <#{SecureRandom.uuid}@example.test>
      MIME-Version: 1.0
      Content-Type: text/plain; charset=UTF-8

      #{body}
    MAIL
  end

  it 'routes membership request aliases into membership requests' do
    community = create(:better_together_community, name: 'Email Routed Community')
    platform = create_tenant(community:, domain: 'tenant-a.example.test')
    inbound_email = build_inbound_email(raw_mail(to: "requests+#{community.slug}@tenant-a.example.test", body: 'Please let me join'))

    expect do
      described_class.new(inbound_email).route!
    end.to change(BetterTogether::Joatu::MembershipRequest, :count).by(1)
    expect(BetterTogether::InboundEmailMessage.count).to eq(1)

    message = BetterTogether::InboundEmailMessage.last
    request = BetterTogether::Joatu::MembershipRequest.last
    expect(message).to be_status_routed
    expect(message).to be_route_kind_membership_request
    expect(message.platform).to eq(platform)
    expect(message.target).to eq(community)
    expect(message.routed_record).to eq(request)
    expect(request.requestor_email).to eq('sender@example.test')
  end

  it 'stores community aliases as inbound messages' do
    community = create(:better_together_community, name: 'Community Inbox')
    platform = create_tenant(community:, domain: 'tenant-b.example.test')
    inbound_email = build_inbound_email(raw_mail(to: "community+#{community.slug}@tenant-b.example.test"))

    expect do
      described_class.new(inbound_email).route!
    end.to change(BetterTogether::InboundEmailMessage, :count).by(1)

    message = BetterTogether::InboundEmailMessage.last
    expect(message).to be_route_kind_community
    expect(message).to be_status_received
    expect(message.platform).to eq(platform)
    expect(message.target).to eq(community)
  end

  it 'stores agent aliases against tenant-scoped robots before global fallbacks' do
    tenant_community = create(:better_together_community, name: 'Tenant Scoped Agents')
    platform = create_tenant(community: tenant_community, domain: 'tenant-c.example.test')
    create(:better_together_robot, :global, identifier: 'helper-bot', name: 'Global Helper Bot')
    robot = create(:better_together_robot, platform:, identifier: 'helper-bot', name: 'Tenant Helper Bot')
    inbound_email = build_inbound_email(raw_mail(to: "agent+#{robot.identifier}@tenant-c.example.test"))

    described_class.new(inbound_email).route!

    message = BetterTogether::InboundEmailMessage.last
    expect(message).to be_route_kind_agent
    expect(message.platform).to eq(platform)
    expect(message.target).to eq(robot)
  end

  it 'routes agent aliases to people only when they belong to the tenant platform' do
    tenant_community = create(:better_together_community, name: 'Tenant Member Agents')
    platform = create_tenant(community: tenant_community, domain: 'tenant-d.example.test')
    person = create(:better_together_person, identifier: 'member-agent')
    create(:better_together_person_platform_membership, member: person, joinable: platform, status: 'active')
    inbound_email = build_inbound_email(raw_mail(to: 'agent+member-agent@tenant-d.example.test'))

    described_class.new(inbound_email).route!

    message = BetterTogether::InboundEmailMessage.last
    expect(message).to be_route_kind_agent
    expect(message.platform).to eq(platform)
    expect(message.target).to eq(person)
  end

  it 'rejects aliases for unmapped recipient domains' do
    inbound_email = build_inbound_email(raw_mail(to: 'unknown@example.test'))

    expect do
      described_class.new(inbound_email).route!
    end.to change(BetterTogether::InboundEmailMessage, :count).by(1)

    message = BetterTogether::InboundEmailMessage.last
    expect(message).to be_route_kind_unresolved
    expect(message).to be_status_rejected
    expect(message.platform).to be_nil
    expect(message.target).to be_nil
    expect(BetterTogether::Joatu::MembershipRequest.count).to eq(0)
  end

  it 'rejects cross-tenant community aliases instead of leaking across platforms' do
    first_community = create(:better_together_community, name: 'Tenant One')
    create_tenant(community: first_community, domain: 'tenant-one.example.test')
    second_community = create(:better_together_community, name: 'Tenant Two')
    create_tenant(community: second_community, domain: 'tenant-two.example.test')
    inbound_email = build_inbound_email(raw_mail(to: "community+#{second_community.slug}@tenant-one.example.test"))

    described_class.new(inbound_email).route!

    message = BetterTogether::InboundEmailMessage.last
    expect(message).to be_route_kind_unresolved
    expect(message).to be_status_rejected
    expect(message.platform.identifier).to eq(first_community.primary_platform.identifier)
    expect(message.target).to be_nil
  end
end
