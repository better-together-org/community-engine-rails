# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ContentSecurity::RichTextSubjectSync, type: :service do
  let(:png_data) do
    # rubocop:disable Layout/LineLength
    "\x89PNG\r\n\x1A\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\b\x06\x00\x00\x00\x1F\x15\xC4\x89\x00\x00\x00\nIDATx\x9Cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xB4\x00\x00\x00\x00IEND\xAEB`\x82"
    # rubocop:enable Layout/LineLength
  end

  let(:blob) do
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(png_data),
      filename: 'embedded.png',
      content_type: 'image/png'
    )
  end
  let(:second_blob) do
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(png_data),
      filename: 'embedded-2.png',
      content_type: 'image/png'
    )
  end
  let(:attachment_html) { ActionText::Attachment.from_attachable(blob).to_html }
  let(:second_attachment_html) { ActionText::Attachment.from_attachable(second_blob).to_html }

  it 'creates held subject rows for embedded blobs and prunes removed embeds' do
    message = BetterTogether::Message.create!(
      conversation: create(:conversation),
      sender: create(:person),
      content: "<p>hello</p>#{attachment_html}"
    )

    subject = BetterTogether::ContentSecurity::Subject.find_by(
      subject: message,
      attachment_name: "content:embed:#{blob.id}"
    )

    expect(subject).to be_present
    expect(subject.active_storage_blob).to eq(blob)
    expect(subject.lifecycle_state).to eq('pending_scan')
    expect(subject.aggregate_verdict).to eq('review_required')
    expect(subject.current_visibility_state).to eq('private')

    message.update!(content: '<p>hello again</p>')

    expect(
      BetterTogether::ContentSecurity::Subject.find_by(subject: message, attachment_name: "content:embed:#{blob.id}")
    ).to be_nil
  end

  it 'allows multiple embedded blobs in the same rich text locale' do
    expect do
      BetterTogether::Message.create!(
        conversation: create(:conversation),
        sender: create(:person),
        content: "<p>hello</p>#{attachment_html}#{second_attachment_html}"
      )
    end.not_to raise_error

    expect(BetterTogether::ContentSecurity::Subject.find_by(attachment_name: "content:embed:#{blob.id}")).to be_present
    expect(BetterTogether::ContentSecurity::Subject.find_by(attachment_name: "content:embed:#{second_blob.id}")).to be_present
  end
end
