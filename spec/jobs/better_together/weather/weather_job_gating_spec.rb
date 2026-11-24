# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Weather job gating' do # rubocop:disable RSpec/DescribeClass
  include ActiveJob::TestHelper

  let(:jobs) do
    [BetterTogether::Weather::RefreshScanJob, BetterTogether::Weather::BackfillScanJob]
  end
  let(:weather_jobs) do
    jobs + [BetterTogether::Weather::RefreshLocationJob, BetterTogether::Weather::BackfillLocationJob,
            BetterTogether::Weather::PurgeJob]
  end

  around do |example|
    original = BetterTogether.weather_enabled
    example.run
  ensure
    BetterTogether.weather_enabled = original
  end

  def enqueue_everything(location_id)
    jobs.each(&:perform_later)
    BetterTogether::Weather::RefreshLocationJob.perform_later(location_id)
    BetterTogether::Weather::BackfillLocationJob.perform_later(location_id)
  end

  shared_examples 'weather is off' do
    it 'enqueues nothing from the scheduler, the location callback or the scan jobs' do
      id = location_id
      clear_enqueued_jobs
      assert_no_enqueued_jobs(only: weather_jobs) do
        enqueue_everything(id)
        jobs.each(&:perform_now)
        BetterTogether::Weather::Location.find_by(id:)&.send(:schedule_initial_load)
      end
    end

    it 'returns from already queued jobs without calling the source' do
      allow(BetterTogether::Weather::RefreshLocation).to receive(:call)
      allow(BetterTogether::Weather::BackfillObservations).to receive(:call)

      BetterTogether::Weather::RefreshLocationJob.perform_now(location_id)
      BetterTogether::Weather::BackfillLocationJob.perform_now(location_id)

      expect(BetterTogether::Weather::RefreshLocation).not_to have_received(:call)
      expect(BetterTogether::Weather::BackfillObservations).not_to have_received(:call)
    end
  end

  context 'with no source at all' do
    let(:location_id) { SecureRandom.uuid }

    it_behaves_like 'weather is off'

    it 'reports weather as not enabled' do
      expect(BetterTogether::Weather.enabled?).to be(false)
    end
  end

  context 'with only a disabled source' do
    let(:location_id) { create(:weather_location, source: create(:weather_source, enabled: false)).id }

    it_behaves_like 'weather is off'
  end

  context 'with an enabled source but no enabled location' do
    let(:location_id) { create(:weather_location, enabled: false).id }

    it_behaves_like 'weather is off'
  end

  context 'with the feature switched off and an enabled source' do
    let(:location_id) { create(:weather_location).id }

    before { BetterTogether.weather_enabled = false }

    it_behaves_like 'weather is off'
  end

  context 'with the feature on and an enabled source' do
    let!(:location) { create(:weather_location) }

    before { clear_enqueued_jobs }

    it 'reports weather as enabled' do
      expect(BetterTogether::Weather.enabled?).to be(true)
    end

    it 'enqueues the scheduled scans and their per-location jobs' do
      jobs.each(&:perform_later)
      expect(enqueued_jobs.size).to eq(2)

      jobs.each(&:perform_now)
      expect(BetterTogether::Weather::RefreshLocationJob).to have_been_enqueued.with(location.id)
      expect(BetterTogether::Weather::BackfillLocationJob).to have_been_enqueued.with(location.id)
    end

    it 'spreads refresh enqueues a few seconds apart' do
      second = create(:weather_location)
      clear_enqueued_jobs
      BetterTogether::Weather::RefreshScanJob.perform_now

      waits = enqueued_jobs.map { |job| job[:at] }.compact
      expect(enqueued_jobs.map { |job| job[:args].first }).to contain_exactly(location.id, second.id)
      expect(waits.uniq.size).to eq(waits.size)
    end
  end

  describe BetterTogether::Weather::PurgeJob do
    it 'is neither queued nor run when nothing is stored' do
      allow(BetterTogether::Weather::Retention).to receive(:new)

      assert_no_enqueued_jobs { described_class.perform_later }
      expect(described_class.perform_now).to be_nil
      expect(BetterTogether::Weather::Retention).not_to have_received(:new)
    end

    it 'still runs retention for stored readings after every source is disabled' do
      observation = create(:weather_observation)
      observation.location.source.update!(enabled: false)
      clear_enqueued_jobs

      expect { described_class.perform_later }.to have_enqueued_job(described_class)
      expect(described_class.perform_now(dry_run: true)).to include(dry_run: true)
    end
  end
end
