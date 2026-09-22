# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::RouterMailbox do
  def build_inbound_email(raw_source)
    ActionMailbox::InboundEmail.create_and_extract_message_id!(raw_source)
  end

  it 'delegates inbound mail processing to the routing service' do
    inbound_email = build_inbound_email(<<~MAIL)
      From: sender@example.test
      To: community+demo@tenant.example.test
      Subject: Hello
      Message-ID: <#{SecureRandom.uuid}@example.test>
      MIME-Version: 1.0
      Content-Type: text/plain; charset=UTF-8

      Plain text body
    MAIL
    service = instance_double(BetterTogether::InboundEmailRoutingService, route!: true)

    allow(BetterTogether::InboundEmailRoutingService).to receive(:new).with(inbound_email).and_return(service)

    described_class.receive(inbound_email)

    expect(BetterTogether::InboundEmailRoutingService).to have_received(:new).with(inbound_email)
    expect(service).to have_received(:route!)
  end
end
