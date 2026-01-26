# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Metrics::OrphanedRichTextLinkCleanupJob do
  include ActiveJob::TestHelper

  describe '#perform' do
    context 'when there are no rich text links' do
      it 'completes without errors' do
        expect do
          described_class.perform_now
        end.not_to raise_error
      end

      it 'logs zero cleanup count' do
        allow(Rails.logger).to receive(:info)

        described_class.perform_now

        expect(Rails.logger).to have_received(:info).with(/Total links cleaned up: 0/)
      end
    end
  end
end
