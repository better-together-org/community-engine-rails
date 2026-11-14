# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/VerifiedDoubles
RSpec.describe BetterTogether::ContentSecurity::MailScreeningPayloadBuilder, type: :service do
  subject(:builder) do
    described_class.new(
      inbound_email:,
      mail:,
      resolution:,
      sender:,
      body_plain:
    )
  end

  let(:inbound_email) { double('inbound_email', id: 7, message_id: 'msg-abc') }
  let(:mail_attachment) do
    double('mail_attachment',
           filename: 'report.pdf',
           mime_type: 'application/pdf',
           body: double('body', decoded: 'binary content'))
  end
  let(:mail) do
    double('mail',
           encoded: 'RAW EMAIL',
           mime_type: 'message/rfc822',
           subject: 'Hello',
           message_id: 'msg-abc',
           attachments: [mail_attachment])
  end
  let(:platform) { double('platform', identifier: 'my-platform') }
  let(:resolution) do
    double('resolution',
           platform: platform,
           recipient_domain: 'example.com',
           recipient_address: 'inbox@example.com')
  end
  # rubocop:disable RSpec/VerifiedDoubles
  let(:sender) { double('sender', address: 'sender@example.com') }
  let(:body_plain) { 'Hello, this is the body.' }
  let(:message) do
    double('message', id: 99, message_id: 'msg-abc')
  end
  # rubocop:enable RSpec/VerifiedDoubles

  describe '#call' do
    let(:payloads) { builder.call(message) }

    it 'returns an array with one entry per body plus one per attachment' do
      expect(payloads.size).to eq(2)
    end

    describe 'message payload (first element)' do
      subject(:payload) { payloads.first }

      it 'has the expected top-level keys' do
        expect(payload.keys).to include(:tenant, :source, :object, :content_text,
                                        :trigger_event, :privacy, :visibility, :ai_ingestion)
      end

      it 'sets trigger_event to ce_inbound_email_received' do
        expect(payload[:trigger_event]).to eq('ce_inbound_email_received')
      end

      it 'marks privacy as community_private with personal data' do
        expect(payload[:privacy][:contains_personal_data]).to be true
        expect(payload[:privacy][:sensitivity_level]).to eq('community_private')
      end

      it 'excludes AI ingestion' do
        expect(payload[:ai_ingestion][:eligibility]).to eq('excluded')
      end

      it 'uses the platform identifier as tenant_key when platform is present' do
        expect(payload[:tenant][:tenant_key]).to eq('my-platform')
        expect(payload[:tenant][:tenant_type]).to eq('ce_app')
      end

      it 'sets the source surface to mail' do
        expect(payload[:source][:surface]).to eq('mail')
      end

      it 'includes a sha256 primary_digest on the object' do
        expect(payload[:object][:primary_digest][:algorithm]).to eq('sha256')
        expect(payload[:object][:primary_digest][:value]).to match(/\A[0-9a-f]{64}\z/)
      end

      it 'includes sender address in content_text' do
        expect(payload[:content_text]).to include('sender@example.com')
      end

      it 'includes an attachment manifest when attachments are present' do
        expect(payload[:content_text]).to include('report.pdf')
      end
    end

    describe 'attachment payload (second element)' do
      subject(:payload) { payloads[1] }

      it 'sets content_kind to file' do
        expect(payload[:object][:content_kind]).to eq('file')
      end

      it 'includes the attachment filename' do
        expect(payload[:object][:filename]).to eq('report.pdf')
      end

      it 'sets the source surface to mail' do
        expect(payload[:source][:surface]).to eq('mail')
      end

      it 'includes the raw decoded attachment bytes for malware scanning' do
        expect(payload[:raw_content]).to eq('binary content')
      end
    end

    describe 'message payload raw_content' do
      it 'is nil for the message body payload' do
        expect(payloads.first[:raw_content]).to be_nil
      end
    end

    context 'when the resolution has no platform' do
      before { allow(resolution).to receive(:platform).and_return(nil) }

      it 'uses the recipient_domain as tenant_key' do
        expect(payloads.first[:tenant][:tenant_key]).to eq('example.com')
        expect(payloads.first[:tenant][:tenant_type]).to eq('mailbox')
      end
    end

    context 'when there are no mail attachments' do
      before { allow(mail).to receive(:attachments).and_return([]) }

      it 'returns only the message payload' do
        expect(builder.call(message).size).to eq(1)
      end

      it 'omits the attachment manifest from content_text' do
        payload = builder.call(message).first
        expect(payload[:content_text]).not_to include('attachments:')
      end
    end
  end
end
# rubocop:enable RSpec/VerifiedDoubles
