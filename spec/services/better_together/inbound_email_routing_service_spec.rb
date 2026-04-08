# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::InboundEmailRoutingService do
  class FakeScannerRunner
    attr_reader :payloads

    def initialize(results:)
      @results = results
      @payloads = []
    end

    def call(payload)
      @payloads << payload.deep_dup
      @results.fetch(@payloads.length - 1, @results.last)
    end
  end

  def build_inbound_email(raw_source)
    ActionMailbox::InboundEmail.create_and_extract_message_id!(raw_source)
  end

  def create_tenant(community:, domain:)
    platform = create(:better_together_platform, community:, host_url: "https://#{domain}")
    platform.platform_domains.find_or_create_by!(hostname: domain) do |platform_domain|
      platform_domain.primary = true
      platform_domain.active = true
    end
    platform
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

  def multipart_mail(to:, attachments:, from: 'sender@example.test', subject: 'Test subject', body: 'Plain body')
    boundary = "BOUNDARY-#{SecureRandom.uuid}"
    attachment_parts = attachments.map do |attachment|
      <<~PART
        --#{boundary}
        Content-Type: #{attachment.fetch(:content_type)}
        Content-Disposition: attachment; filename="#{attachment.fetch(:filename)}"
        Content-Transfer-Encoding: 7bit

        #{attachment.fetch(:body)}
      PART
    end.join

    <<~MAIL
      From: Sender Example <#{from}>
      To: #{to}
      Subject: #{subject}
      Message-ID: <#{SecureRandom.uuid}@example.test>
      MIME-Version: 1.0
      Content-Type: multipart/mixed; boundary="#{boundary}"

      --#{boundary}
      Content-Type: text/plain; charset=UTF-8

      #{body}
      #{attachment_parts}
      --#{boundary}--
    MAIL
  end

  def scanner_result(verdict: 'clean', finding_summary: nil)
    finding = finding_summary.present? ? [{ 'summary' => finding_summary }] : []

    {
      'content_item' => { 'aggregate_verdict' => verdict },
      'findings' => finding,
      'records' => [{ 'record_type' => 'content_item', 'aggregate_verdict' => verdict }]
    }
  end

  it 'routes membership request aliases into membership requests' do
    community = create(:better_together_community, name: 'Email Routed Community')
    platform = create_tenant(community:, domain: 'tenant-a.example.test')
    inbound_email = build_inbound_email(raw_mail(to: "requests+#{community.slug}@tenant-a.example.test", body: 'Please let me join'))
    scanner_runner = FakeScannerRunner.new(results: [scanner_result])

    expect do
      described_class.new(inbound_email, scanner_runner:).route!
    end.to change(BetterTogether::Joatu::MembershipRequest, :count).by(1)
    expect(BetterTogether::InboundEmailMessage.count).to eq(1)

    message = BetterTogether::InboundEmailMessage.last
    request = BetterTogether::Joatu::MembershipRequest.last
    expect(message).to be_status_routed
    expect(message).to be_route_kind_membership_request
    expect(message.platform).to eq(platform)
    expect(message.target).to eq(community)
    expect(message).to be_screening_state_passed
    expect(message.screening_verdict).to eq('clean')
    expect(message.routed_record).to eq(request)
    expect(request.requestor_email).to eq('sender@example.test')
  end

  it 'stores community aliases as inbound messages' do
    community = create(:better_together_community, name: 'Community Inbox')
    platform = create_tenant(community:, domain: 'tenant-b.example.test')
    inbound_email = build_inbound_email(raw_mail(to: "community+#{community.slug}@tenant-b.example.test"))
    scanner_runner = FakeScannerRunner.new(results: [scanner_result])

    expect do
      described_class.new(inbound_email, scanner_runner:).route!
    end.to change(BetterTogether::InboundEmailMessage, :count).by(1)

    message = BetterTogether::InboundEmailMessage.last
    expect(message).to be_route_kind_community
    expect(message).to be_status_received
    expect(message).to be_screening_state_passed
    expect(message.platform).to eq(platform)
    expect(message.target).to eq(community)
  end

  it 'stores agent aliases against tenant-scoped robots before global fallbacks' do
    tenant_community = create(:better_together_community, name: 'Tenant Scoped Agents')
    platform = create_tenant(community: tenant_community, domain: 'tenant-c.example.test')
    create(:better_together_robot, :global, identifier: 'helper-bot', name: 'Global Helper Bot')
    robot = create(:better_together_robot, platform:, identifier: 'helper-bot', name: 'Tenant Helper Bot')
    inbound_email = build_inbound_email(raw_mail(to: "agent+#{robot.identifier}@tenant-c.example.test"))
    scanner_runner = FakeScannerRunner.new(results: [scanner_result])

    described_class.new(inbound_email, scanner_runner:).route!

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
    scanner_runner = FakeScannerRunner.new(results: [scanner_result])

    described_class.new(inbound_email, scanner_runner:).route!

    message = BetterTogether::InboundEmailMessage.last
    expect(message).to be_route_kind_agent
    expect(message.platform).to eq(platform)
    expect(message.target).to eq(person)
  end

  it 'rejects aliases for unmapped recipient domains' do
    inbound_email = build_inbound_email(raw_mail(to: 'unknown@example.test'))
    scanner_runner = FakeScannerRunner.new(results: [scanner_result])

    expect do
      described_class.new(inbound_email, scanner_runner:).route!
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
    first_platform = create_tenant(community: first_community, domain: 'tenant-one.example.test')
    second_community = create(:better_together_community, name: 'Tenant Two')
    create_tenant(community: second_community, domain: 'tenant-two.example.test')
    inbound_email = build_inbound_email(raw_mail(to: "community+#{second_community.slug}@tenant-one.example.test"))
    scanner_runner = FakeScannerRunner.new(results: [scanner_result])

    described_class.new(inbound_email, scanner_runner:).route!

    message = BetterTogether::InboundEmailMessage.last
    expect(message).to be_route_kind_unresolved
    expect(message).to be_status_rejected
    expect(message.platform).to eq(first_platform)
    expect(message.target).to be_nil
  end

  it 'holds membership requests before downstream creation when screening requires review' do
    community = create(:better_together_community, name: 'Held Membership Requests')
    create_tenant(community:, domain: 'tenant-hold.example.test')
    inbound_email = build_inbound_email(raw_mail(to: "requests+#{community.slug}@tenant-hold.example.test"))
    scanner_runner = FakeScannerRunner.new(results: [scanner_result(verdict: 'review_required', finding_summary: 'High-risk attachment detected')])

    expect do
      described_class.new(inbound_email, scanner_runner:).route!
    end.not_to change(BetterTogether::Joatu::MembershipRequest, :count)

    message = BetterTogether::InboundEmailMessage.last
    expect(message).to be_status_received
    expect(message).to be_screening_state_held
    expect(message.screening_verdict).to eq('review_required')
    expect(message.content_screening_summary).to include('High-risk attachment detected')
  end

  it 'screens attachment metadata alongside the email body before routing' do
    community = create(:better_together_community, name: 'Attachment Intake')
    create_tenant(community:, domain: 'tenant-attachments.example.test')
    inbound_email = build_inbound_email(
      multipart_mail(
        to: "requests+#{community.slug}@tenant-attachments.example.test",
        attachments: [{ filename: 'dangerous.exe', content_type: 'application/octet-stream', body: 'payload' }]
      )
    )
    scanner_runner = FakeScannerRunner.new(results: [scanner_result, scanner_result(verdict: 'review_required', finding_summary: 'Executable attachment detected')])

    described_class.new(inbound_email, scanner_runner:).route!

    expect(scanner_runner.payloads.length).to eq(2)
    expect(scanner_runner.payloads.first.dig(:source, :surface)).to eq('mail')
    expect(scanner_runner.payloads.second.dig(:object, :filename)).to eq('dangerous.exe')

    message = BetterTogether::InboundEmailMessage.last
    expect(message).to be_screening_state_held
    expect(message.content_security_records).not_to be_empty
  end
end
