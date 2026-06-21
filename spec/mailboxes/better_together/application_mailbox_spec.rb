# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ApplicationMailbox do
  def build_inbound_email(raw_source)
    ActionMailbox::InboundEmail.create_and_extract_message_id!(raw_source)
  end

  it 'uses the CE router mailbox by default' do
    inbound_email = build_inbound_email(<<~MAIL)
      From: sender@example.test
      To: community+demo@tenant.example.test
      Subject: Hello
      Message-ID: <#{SecureRandom.uuid}@example.test>
      MIME-Version: 1.0
      Content-Type: text/plain; charset=UTF-8

      Plain text body
    MAIL

    expect(described_class.mailbox_for(inbound_email)).to eq(BetterTogether::RouterMailbox)
  end
end
