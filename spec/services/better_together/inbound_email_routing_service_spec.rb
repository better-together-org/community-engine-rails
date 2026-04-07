# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::InboundEmailRoutingService do
  def build_inbound_email(raw_source)
    ActionMailbox::InboundEmail.create_and_extract_message_id!(raw_source)
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
    inbound_email = build_inbound_email(raw_mail(to: "requests+#{community.slug}@example.test", body: 'Please let me join'))

    expect do
      described_class.new(inbound_email).route!
    end.to change(BetterTogether::Joatu::MembershipRequest, :count).by(1)
    expect(BetterTogether::InboundEmailMessage.count).to eq(1)

    message = BetterTogether::InboundEmailMessage.last
    request = BetterTogether::Joatu::MembershipRequest.last
    expect(message).to be_status_routed
    expect(message).to be_route_kind_membership_request
    expect(message.target).to eq(community)
    expect(message.routed_record).to eq(request)
    expect(request.requestor_email).to eq('sender@example.test')
  end

  it 'stores community aliases as inbound messages' do
    community = create(:better_together_community, name: 'Community Inbox')
    inbound_email = build_inbound_email(raw_mail(to: "community+#{community.slug}@example.test"))

    expect do
      described_class.new(inbound_email).route!
    end.to change(BetterTogether::InboundEmailMessage, :count).by(1)

    message = BetterTogether::InboundEmailMessage.last
    expect(message).to be_route_kind_community
    expect(message).to be_status_received
    expect(message.target).to eq(community)
  end

  it 'stores agent aliases against global robots when available' do
    robot = create(:better_together_robot, platform: nil, identifier: 'helper-bot')
    inbound_email = build_inbound_email(raw_mail(to: "agent+#{robot.identifier}@example.test"))

    described_class.new(inbound_email).route!

    message = BetterTogether::InboundEmailMessage.last
    expect(message).to be_route_kind_agent
    expect(message.target).to eq(robot)
  end

  it 'rejects unresolved aliases without routing them downstream' do
    inbound_email = build_inbound_email(raw_mail(to: 'unknown@example.test'))

    expect do
      described_class.new(inbound_email).route!
    end.to change(BetterTogether::InboundEmailMessage, :count).by(1)

    message = BetterTogether::InboundEmailMessage.last
    expect(message).to be_route_kind_unresolved
    expect(message).to be_status_rejected
    expect(message.target).to be_nil
    expect(BetterTogether::Joatu::MembershipRequest.count).to eq(0)
  end
end
