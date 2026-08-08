# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  # rubocop:todo RSpec/SpecFilePathFormat
  RSpec.describe ActiveStorageVariantErrorHandling do
    # rubocop:enable RSpec/SpecFilePathFormat

    # Build a minimal anonymous controller that includes the concern so we can
    # unit-test the rescue handler without standing up full AS routing.
    let(:controller_class) do
      Class.new(ActionController::Base) do
        include BetterTogether::ActiveStorageVariantErrorHandling
      end
    end

    let(:controller) { controller_class.new }
    let(:blob) { instance_double(ActiveStorage::Blob, id: 'blob-id-123') }
    let(:exception) { Vips::Error.new('matload: operation is blocked') }

    before do
      controller.instance_variable_set(:@_response, ActionDispatch::TestResponse.create)
    end

    describe '#handle_variant_processing_error' do
      before { controller.instance_variable_set(:@blob, blob) }

      it 'renders 422 instead of letting the exception propagate' do
        expect(controller).to receive(:head).with(:unprocessable_entity)
        controller.send(:handle_variant_processing_error, exception)
      end

      it 'logs the failing blob id and exception details' do
        allow(controller).to receive(:head)
        expect(Rails.logger).to receive(:warn).with(a_string_matching(/blob-id-123.*Vips::Error/))
        controller.send(:handle_variant_processing_error, exception)
      end

      context 'when @blob is not set' do
        before { controller.instance_variable_set(:@blob, nil) }

        it 'still renders 422 without raising' do
          expect(controller).to receive(:head).with(:unprocessable_entity)
          controller.send(:handle_variant_processing_error, exception)
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
