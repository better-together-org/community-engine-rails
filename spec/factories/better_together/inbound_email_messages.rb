# frozen_string_literal: true

FactoryBot.define do
  factory('better_together/inbound_email_message',
          class: 'BetterTogether::InboundEmailMessage',
          aliases: %i[better_together_inbound_email_message inbound_email_message]) do
    association :inbound_email, factory: :action_mailbox_inbound_email
    association :platform, factory: :better_together_platform
    route_kind { 'community' }
    status { 'received' }
    association :target, factory: :better_together_community
    message_id { SecureRandom.uuid }
    sender_email { 'sender@example.test' }
    sender_name { 'Sender Example' }
    recipient_address { 'community+demo@example.test' }
    recipient_local_part { 'community+demo' }
    recipient_domain { 'example.test' }
    subject { 'Hello' }
    body_plain { 'Plain text body' }
    screening_state { 'pending' }
    screening_verdict { nil }
    content_screening_summary { nil }
    content_security_records_json { nil }
  end

  factory :action_mailbox_inbound_email, class: 'ActionMailbox::InboundEmail' do
    transient do
      source do
        <<~MAIL
          From: sender@example.test
          To: community+demo@example.test
          Subject: Hello
          Message-ID: <#{SecureRandom.uuid}@example.test>
          MIME-Version: 1.0
          Content-Type: text/plain; charset=UTF-8

          Plain text body
        MAIL
      end
    end

    initialize_with { ActionMailbox::InboundEmail.create_and_extract_message_id!(source) }
  end
end
