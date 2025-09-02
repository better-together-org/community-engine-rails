# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe Metrics::RichTextLinkIdentifier do
    let(:rich_text) { create(:content_rich_text, body: '<a href="https://example.com/foo">link</a>') }

    it 'creates link and rich_text_link records' do
      result = described_class.call(rich_texts: [rich_text])

      expect(result[:valid]).to eq(1)
      link = BetterTogether::Content::Link.find_by(url: 'https://example.com/foo')
      expect(link).not_to be_nil
      expect(BetterTogether::Metrics::RichTextLink.where(rich_text_id: rich_text.id).count).to eq(1)
    end
  end
end
