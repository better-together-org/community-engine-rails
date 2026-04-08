# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ContentSecurity::MailScreeningService do
  class RaisingScannerRunner
    def call(_payload)
      raise BetterTogether::ContentSecurity::OrchestratorRunner::Error, 'scanner unavailable'
    end
  end

  def build_inbound_email(raw_source)
    ActionMailbox::InboundEmail.create_and_extract_message_id!(raw_source)
  end

  def raw_mail(to:, body: 'Plain body')
    <<~MAIL
      From: Sender Example <sender@example.test>
      To: #{to}
      Subject: Test subject
      Message-ID: <#{SecureRandom.uuid}@example.test>
      MIME-Version: 1.0
      Content-Type: text/plain; charset=UTF-8

      #{body}
    MAIL
  end

  def create_tenant(community:, domain:)
    platform = BetterTogether::Platform.find_or_initialize_by(url: "https://#{domain}")
    platform.community = community
    platform.name = "#{community.name} Platform"
    platform.identifier ||= "platform-#{SecureRandom.hex(6)}"
    platform.time_zone = 'UTC'
    platform.privacy = 'private'
    platform.external = false
    platform.save!

    platform.platform_domains.find_or_create_by!(hostname: domain) do |platform_domain|
      platform_domain.primary = true
      platform_domain.active = true
    end

    platform
  end

  it 'fails closed when the shared scanner is unavailable' do
    community = create(:better_together_community, name: 'Screening Fail Closed')
    platform = create_tenant(community:, domain: 'tenant-screening.example.test')
    inbound_email = build_inbound_email(raw_mail(to: "community+#{community.slug}@tenant-screening.example.test"))
    message = build(
      :inbound_email_message,
      inbound_email:,
      platform:,
      target: community,
      recipient_address: "community+#{community.slug}@tenant-screening.example.test",
      recipient_local_part: "community+#{community.slug}",
      recipient_domain: 'tenant-screening.example.test'
    )
    resolution = BetterTogether::InboundEmailResolutionService::Resolution.new(
      'community',
      community,
      platform,
      message.recipient_address,
      message.recipient_local_part,
      message.recipient_domain
    )
    sender = Mail::Address.new('Sender Example <sender@example.test>')

    message.save!

    result = described_class
             .new(
               inbound_email:,
               mail: inbound_email.mail,
               resolution:,
               sender:,
               body_plain: 'Plain body',
               scanner_runner: RaisingScannerRunner.new
             )
             .screen!(message)

    expect(result.allow_routing?).to be(false)
    expect(message.reload).to be_screening_state_error
    expect(message.content_screening_summary).to include('scanner unavailable')
  end
end
