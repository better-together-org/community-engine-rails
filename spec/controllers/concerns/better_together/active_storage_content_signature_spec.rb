# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  # rubocop:todo RSpec/SpecFilePathFormat
  RSpec.describe ActiveStorageContentSignature do
    # rubocop:enable RSpec/SpecFilePathFormat

    let(:controller_class) do
      Class.new(ActionController::Base) do
        include BetterTogether::ActiveStorageContentSignature
      end
    end

    let(:controller) { controller_class.new }

    before do
      controller.instance_variable_set(:@_response, ActionDispatch::TestResponse.create)
    end

    describe '#verify_content_signature' do
      let(:blob) do
        instance_double(ActiveStorage::Blob, id: 'blob-id', content_type: declared_type, filename: filename)
      end

      before do
        controller.instance_variable_set(:@blob, blob)
        allow(blob).to receive(:download_chunk).with(0...described_class::CONTENT_SIGNATURE_SNIFF_BYTES)
                                               .and_return(bytes)
      end

      context 'when the blob is not present' do
        let(:declared_type) { 'image/png' }
        let(:filename) { ActiveStorage::Filename.new('avatar.png') }
        let(:bytes) { "\x89PNG\r\n\x1a\n".b }

        it 'does not render' do
          controller.instance_variable_set(:@blob, nil)
          expect(controller).not_to receive(:head)
          controller.send(:verify_content_signature)
        end
      end

      context 'when the real content matches the declared type' do
        let(:declared_type) { 'image/png' }
        let(:filename) { ActiveStorage::Filename.new('avatar.png') }
        let(:bytes) { "\x89PNG\r\n\x1a\n".b }

        it 'does not render' do
          expect(controller).not_to receive(:head)
          controller.send(:verify_content_signature)
        end
      end

      context 'when the real content does not match the declared type' do
        let(:declared_type) { 'image/png' }
        let(:filename) { ActiveStorage::Filename.new('avatar.png') }
        let(:bytes) { "PK\x03\x04\x14\x00\x00\x00\x00\x00".b }

        it 'renders 422' do
          expect(controller).to receive(:head).with(:unprocessable_entity)
          controller.send(:verify_content_signature)
        end
      end

      context 'when the real content has no recognizable magic signature' do
        let(:declared_type) { 'image/png' }
        let(:filename) { ActiveStorage::Filename.new('avatar.png') }
        let(:bytes) { 'this is plain text with no strong magic-byte signature' }

        it 'fails open and does not render' do
          expect(controller).not_to receive(:head)
          controller.send(:verify_content_signature)
        end
      end

      context 'when sniffing the content raises' do
        let(:declared_type) { 'image/png' }
        let(:filename) { ActiveStorage::Filename.new('avatar.png') }
        let(:bytes) { "\x89PNG\r\n\x1a\n".b }

        it 'fails open and does not render' do
          allow(blob).to receive(:download_chunk).and_raise(StandardError, 'storage unavailable')
          expect(controller).not_to receive(:head)
          controller.send(:verify_content_signature)
        end
      end
    end

    describe 'initializer wires up AS proxy and redirect controllers' do
      it 'includes the concern in ActiveStorage::Blobs::ProxyController' do
        expect(ActiveStorage::Blobs::ProxyController.ancestors).to include(described_class)
      end

      it 'includes the concern in ActiveStorage::Blobs::RedirectController' do
        expect(ActiveStorage::Blobs::RedirectController.ancestors).to include(described_class)
      end

      it 'includes the concern in ActiveStorage::Representations::ProxyController' do
        expect(ActiveStorage::Representations::ProxyController.ancestors).to include(described_class)
      end

      it 'includes the concern in ActiveStorage::Representations::RedirectController' do
        expect(ActiveStorage::Representations::RedirectController.ancestors).to include(described_class)
      end
    end
  end
end
