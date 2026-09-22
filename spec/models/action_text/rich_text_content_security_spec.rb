# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActionText::RichText do
  let(:message) { build(:message, content: nil) }

  describe 'embedded attachment validation' do
    it 'rejects remote images that bypass CE blob review' do
      rich_text = described_class.new(
        name: 'content',
        record: message,
        body: <<~HTML
          <p>Hello</p>
          <action-text-attachment url="https://example.com/unsafe.png" content-type="image/png" width="1" height="1"></action-text-attachment>
        HTML
      )

      expect(rich_text).not_to be_valid
      expect(rich_text.errors[:body])
        .to include('contains unsupported attachments; upload files into CE so they can be reviewed first')
    end
  end
end
