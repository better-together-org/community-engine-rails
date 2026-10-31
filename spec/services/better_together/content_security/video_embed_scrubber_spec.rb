# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ContentSecurity::VideoEmbedScrubber do
  let(:host) { BetterTogether::Content::VideoBlock::PRIVACY_EMBED_HOST }

  def scrub(html)
    Rails::HTML5::SafeListSanitizer.new.sanitize(html, scrubber: described_class.new)
  end

  def attachment(src)
    "<action-text-attachment sgid=\"x\"><figure><div><iframe src=\"#{src}\" allowfullscreen></iframe></div></figure>" \
      '</action-text-attachment>'
  end

  it 'keeps the privacy-enhanced youtube iframe inside an attachment', :aggregate_failures do
    html = scrub(attachment("#{host}abc"))

    expect(html).to include('<iframe', "src=\"#{host}abc\"", 'allowfullscreen')
  end

  it 'removes an iframe from any other host, even inside an attachment' do
    expect(scrub(attachment('https://evil.example/embed/abc'))).not_to include('<iframe')
  end

  it 'removes an iframe that is not inside an attachment' do
    expect(scrub("<p><iframe src=\"#{host}abc\"></iframe></p>")).not_to include('<iframe')
  end

  it 'still removes script' do
    expect(scrub('<p>Hi</p><script>alert(1)</script>')).not_to include('<script')
  end
end
