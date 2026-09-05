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
    let!(:other_platform) { create(:better_together_platform) }
    let!(:other_platform_case) { create(:safety_case, platform: other_platform, harm_level: 'urgent') }

    it 'calls the LocalReviewSnapshotService once per platform' do
      service = instance_double(BetterTogether::Safety::LocalReviewSnapshotService, call: {})
      allow(BetterTogether::Safety::LocalReviewSnapshotService).to receive(:new).and_return(service)

      job.perform

      expect(service).to have_received(:call).exactly(BetterTogether::Platform.count).times
    end

    it "writes a per-platform snapshot reflecting only that platform's cases" do
      allow(Rails.cache).to receive(:write)

      job.perform

      expect(Rails.cache).to have_received(:write).with(
        BetterTogether::Safety::LocalReviewSnapshotService.cache_key_for(other_platform),
        hash_including(open_cases_count: 1, urgent_open_cases_count: 1),
        expires_in: 15.minutes
      )
    end

    it "does not leak another platform's cases into an unrelated platform's snapshot" do
      empty_platform = create(:better_together_platform)
      allow(Rails.cache).to receive(:write)

      job.perform

      expect(Rails.cache).to have_received(:write).with(
        BetterTogether::Safety::LocalReviewSnapshotService.cache_key_for(empty_platform),
        hash_including(open_cases_count: 0, urgent_open_cases_count: 0),
        expires_in: 15.minutes
      )
    end
  end
end
