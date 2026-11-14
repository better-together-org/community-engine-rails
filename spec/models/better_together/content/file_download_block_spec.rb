# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Content
    RSpec.describe FileDownloadBlock do
      subject(:block) { described_class.new(upload_id: upload.id) }

      let(:upload) do
        create(:better_together_upload).tap do |record|
          record.file.attach(io: StringIO.new('data'), filename: 'minutes.pdf', content_type: 'application/pdf')
        end
      end

      it 'is a subclass of Content::Block' do
        expect(described_class.superclass).to eq(BetterTogether::Content::Block)
      end

      it 'is content_addable' do
        expect(described_class.content_addable?).to be true
      end

      it 'requires an upload' do
        block.upload_id = ''
        block.valid?
        expect(block.errors[:upload_id]).not_to be_empty
      end

      it 'is valid with an upload id' do
        expect(block).to be_valid
      end

      it 'defaults to downloading rather than opening inline' do
        expect(block.open_inline?).to be false
      end

      it 'finds its upload' do
        expect(block.upload).to eq(upload)
      end

      it 'returns nil for an unknown upload' do
        block.upload_id = SecureRandom.uuid
        expect(block.upload).to be_nil
      end

      describe '#display_label' do
        it 'prefers the block label' do
          block.label = 'Board minutes'
          expect(block.display_label).to eq('Board minutes')
        end

        it 'falls back to the file name' do
          expect(block.display_label).to eq('minutes.pdf')
        end
      end

      it 'permits all of its attributes' do
        expect(described_class.extra_permitted_attributes).to include(:upload_id, :open_inline, :label, :description)
      end
    end
  end
end
