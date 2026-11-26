# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Orders::PdfAttachments do
  let(:base) do
    receipt = Receipts::Receipt.new
    receipt.title = 'Receipt'
    receipt.render
  end
  let(:attachment) do
    described_class::Attachment.new(name: 'factur-x.xml', content: '<x>é</x>', mime: 'text/xml',
                                    relationship: 'Data', description: 'Factur-X invoice')
  end
  let(:result) do
    described_class.new(base, attachments: [attachment], title: 'Invoice 1', author: 'Seller',
                              created_at: Time.utc(2026, 11, 10, 12)).to_pdf
  end

  it 'keeps the original bytes and appends an update' do
    expect(result.byteslice(0, base.bytesize)).to eq(base.b)
  end

  it 'attaches the file, the metadata and the info, and points back at the first table' do
    expect(result).to include('/AFRelationship /Data', '/EmbeddedFiles', '/Metadata', '<x>é</x>'.b, '/Prev')
  end

  it 'ends with a table that starts where startxref says' do
    start = result[/startxref\s+(\d+)\s+%%EOF\s*\z/, 1].to_i
    expect(result.byteslice(start, 4)).to eq('xref')
  end
end
