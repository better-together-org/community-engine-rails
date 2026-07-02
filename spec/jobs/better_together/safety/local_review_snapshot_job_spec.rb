# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Safety::LocalReviewSnapshotJob do
  subject(:job) { described_class.new }

  describe 'queue configuration' do
    it 'uses the default queue' do
      expect(described_class.queue_name).to eq('default')
    end
  end

  describe '#perform' do
    it 'calls the LocalReviewSnapshotService' do
      service = instance_double(BetterTogether::Safety::LocalReviewSnapshotService, call: {})
      allow(BetterTogether::Safety::LocalReviewSnapshotService).to receive(:new).and_return(service)

      job.perform

      expect(service).to have_received(:call)
    end

    it 'writes the result to Rails cache under the expected key' do
      snapshot = { 'open_cases' => 2 }
      service = instance_double(BetterTogether::Safety::LocalReviewSnapshotService, call: snapshot)
      allow(BetterTogether::Safety::LocalReviewSnapshotService).to receive(:new).and_return(service)

      expect(Rails.cache).to receive(:write).with(
        BetterTogether::Safety::LocalReviewSnapshotService::CACHE_KEY,
        snapshot,
        expires_in: 15.minutes
      )

      job.perform
    end
  end
end
