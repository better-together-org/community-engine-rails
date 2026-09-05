# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/VerifiedDoubles
RSpec.describe BetterTogether::ContentSecurity::RichTextAttachmentFilter, type: :service do
  let(:blob) { double('blob', id: 42, filename: 'doc.pdf') }
  let(:content) { double('action_text_content', blank?: false) }
  let(:renderable_attachment) { double('attachment', attachable: blob, node: '<img src="doc.pdf"/>') }
  let(:held_attachment) { double('attachment', attachable: blob) }

  def stub_subject_chain(return_value)
    ordered = double('ordered', first: return_value)
    allow(BetterTogether::ContentSecurity::Subject).to receive(:for_blob).and_return(double('scope', order: ordered))
  end

  describe '#call' do
    context 'when the content is blank' do
      before { allow(content).to receive(:blank?).and_return(true) }

      it 'returns the content unchanged without calling render_attachments' do
        expect(content).not_to receive(:render_attachments)
        described_class.new(content).call
      end

      it 'returns the original content object' do
        expect(described_class.new(content).call).to eq(content)
      end
    end

    context 'when an attachment is cleared for public proxy' do
      before do
        allow(content).to receive(:render_attachments).and_yield(renderable_attachment)
                                                      .and_return('<img src="doc.pdf"/>')
        allow(renderable_attachment.attachable).to receive(:is_a?).with(ActiveStorage::Blob).and_return(true)
        allow(BetterTogether::ContentSecurity::BlobAccessPolicy)
          .to receive(:public_proxy_allowed?).with(blob).and_return(true)
      end

      it 'returns the attachment node directly' do
        result = content.render_attachments(&:node)
        expect(result).to include('doc.pdf')
      end
    end

    context 'when an attachment is not yet cleared (held for review)' do
      before do
        allow(BetterTogether::ContentSecurity::BlobAccessPolicy)
          .to receive(:public_proxy_allowed?).and_return(false)
        allow(held_attachment.attachable).to receive(:is_a?).with(ActiveStorage::Blob).and_return(true)
        allow(held_attachment.attachable).to receive(:try).with(:filename).and_return(Pathname.new('doc.pdf'))
        stub_subject_chain(nil)
        allow(content).to receive(:render_attachments).and_yield(held_attachment)
      end

      it 'renders a placeholder figure with held-review state' do
        filter = described_class.new(content)
        placeholder = filter.send(:held_attachment_placeholder, held_attachment)
        expect(placeholder.to_s).to include('held-review')
      end

      it 'placeholder has role=status for accessibility' do
        filter = described_class.new(content)
        placeholder = filter.send(:held_attachment_placeholder, held_attachment)
        expect(placeholder.to_s).to include('role="status"')
      end
    end

    context 'when an attachment has a restricted verdict' do
      let(:subject_record) { double('subject', aggregate_verdict: 'blocked') }

      before do
        allow(BetterTogether::ContentSecurity::BlobAccessPolicy)
          .to receive(:public_proxy_allowed?).and_return(false)
        allow(held_attachment.attachable).to receive(:is_a?).with(ActiveStorage::Blob).and_return(true)
        allow(held_attachment.attachable).to receive(:try).with(:filename).and_return(Pathname.new('doc.pdf'))
        stub_subject_chain(subject_record)
      end

      it 'renders a placeholder with content-restricted state' do
        filter = described_class.new(content)
        placeholder = filter.send(:held_attachment_placeholder, held_attachment)
        expect(placeholder.to_s).to include('content-restricted')
      end
    end

    context 'when the attachable is not an ActiveStorage::Blob' do
      let(:non_blob_attachable) { double('non_blob_attachable') }
      let(:non_blob_attachment) { double('attachment', attachable: non_blob_attachable) }

      before do
        allow(non_blob_attachable).to receive(:is_a?).with(ActiveStorage::Blob).and_return(false)
        allow(non_blob_attachable).to receive(:try).with(:filename).and_return(nil)
        stub_subject_chain(nil)
      end

      it 'renders a held placeholder for non-blob attachables' do
        filter = described_class.new(content)
        placeholder = filter.send(:held_attachment_placeholder, non_blob_attachment)
        expect(placeholder).not_to be_nil
      end
    end
  end
end
# rubocop:enable RSpec/VerifiedDoubles
