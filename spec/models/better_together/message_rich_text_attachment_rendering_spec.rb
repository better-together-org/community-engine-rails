# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Message do
  let(:png_data) do
    # rubocop:disable Layout/LineLength
    "\x89PNG\r\n\x1A\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\b\x06\x00\x00\x00\x1F\x15\xC4\x89\x00\x00\x00\nIDATx\x9Cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xB4\x00\x00\x00\x00IEND\xAEB`\x82"
    # rubocop:enable Layout/LineLength
  end

  let(:blob) do
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(png_data),
      filename: 'rendered.png',
      content_type: 'image/png'
    )
  end
  let(:attachment_html) { ActionText::Attachment.from_attachable(blob).to_html }
  let(:message) do
    described_class.create!(
      conversation: create(:conversation),
      sender: create(:person),
      content: "<p>hello</p>#{attachment_html}"
    )
  end

  it 'replaces pending embedded attachments with an accessible review placeholder' do
    rendered = Capybara.string(message.reload.content.to_s)

    expect(rendered).to have_text('hello')
    expect(rendered).to have_css('figure.attachment--held-review')
    expect(rendered).to have_text('Attachment under review')
    expect(rendered).not_to have_css('img')
  end

  it 'renders released public embedded attachments through the content-security proxy' do
    BetterTogether::ContentSecurity::Subject.find_by!(subject: message, attachment_name: "content:embed:#{blob.id}").update!(
      lifecycle_state: 'approved_public',
      aggregate_verdict: 'clean',
      current_visibility_state: 'public',
      current_ai_ingestion_state: 'eligible',
      released_at: Time.current
    )

    rendered = Capybara.string(message.reload.content.to_s)

    expect(rendered).to have_css("img[src*='/content-security/active-storage/representations/proxy/']")
  end
end
