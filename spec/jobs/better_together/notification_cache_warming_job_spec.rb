# frozen_string_literal: true

require 'rails_helper'

module BetterTogether # rubocop:todo Metrics/ModuleLength
  RSpec.describe NotificationCacheWarmingJob do
    include ActiveJob::TestHelper

    let(:notification) { create(:noticed_notification) }
    let(:notification_ids) { [notification.id] }

    describe 'job configuration' do
      it 'is queued on low_priority queue' do
        expect(described_class.queue_name).to eq('low_priority')
      end
    end

    describe '#perform' do
      it 'processes notifications with given ids' do
        # rubocop:todo RSpec/VerifiedDoubles
        relation = double('relation', includes: double('includes_relation', find_each: nil))
        # rubocop:enable RSpec/VerifiedDoubles
        allow(Noticed::Notification).to receive(:where).with(id: notification_ids).and_return(relation)

        described_class.new.perform(notification_ids)

        expect(Noticed::Notification).to have_received(:where).with(id: notification_ids)
      end

      it 'warms cache for eligible notifications' do
        job = described_class.new

        allow(job).to receive(:should_warm_cache?).with(notification).and_return(true)
        expect(job).to receive(:warm_notification_fragments).with(notification)

        job.perform(notification_ids)
      end

      it 'skips ineligible notifications' do
        job = described_class.new

        allow(job).to receive(:should_warm_cache?).with(notification).and_return(false)
        expect(job).not_to receive(:warm_notification_fragments)

        job.perform(notification_ids)
      end

      it 'handles missing notifications gracefully' do
        expect { described_class.new.perform([999_999]) }.not_to raise_error
      end
    end

    describe '#warm_notification_fragments' do
      let(:job) { described_class.new }

      it 'renders notification partial to warm cache' do
        allow(job).to receive_messages(notification_fragment_cache_key: 'test-key',
                                       notification_type_fragment_cache_key: 'test-type-key')
        allow(Rails.cache).to receive(:exist?).and_return(false)

        expect(ApplicationController.renderer).to receive(:render).with(
          partial: notification,
          locals: {},
          formats: [:html]
        )

        job.send(:warm_notification_fragments, notification)
      end

      it 'skips warming if cache already exists' do
        allow(job).to receive_messages(notification_fragment_cache_key: 'test-key',
                                       notification_type_fragment_cache_key: 'test-type-key')
        allow(Rails.cache).to receive(:exist?).and_return(true)

        expect(ApplicationController.renderer).not_to receive(:render)

        job.send(:warm_notification_fragments, notification)
      end

      it 'handles rendering errors gracefully' do
        allow(job).to receive_messages(notification_fragment_cache_key: 'test-key',
                                       notification_type_fragment_cache_key: 'test-type-key')
        allow(Rails.cache).to receive(:exist?).and_return(false)
        allow(ApplicationController.renderer).to receive(:render).and_raise(StandardError.new('Test error'))

        expect(Rails.logger).to receive(:warn).with(/Failed to warm cache/)

        expect { job.send(:warm_notification_fragments, notification) }.not_to raise_error
      end
    end

    describe '#should_warm_cache?' do
      let(:job) { described_class.new }

      it 'returns true for recent notification with record and cache support' do
        record = double('record', present?: true) # rubocop:todo RSpec/VerifiedDoubles
        event = double('event', record: record) # rubocop:todo RSpec/VerifiedDoubles
        notification = double('notification', # rubocop:todo RSpec/VerifiedDoubles
                              event: event,
                              created_at: 1.day.ago,
                              respond_to?: true)

        expect(job.send(:should_warm_cache?, notification)).to be true
      end

      it 'returns false for notification without record' do
        event = double('event', record: double('record', present?: false)) # rubocop:todo RSpec/VerifiedDoubles
        notification = double('notification', # rubocop:todo RSpec/VerifiedDoubles
                              event: event,
                              created_at: 1.day.ago,
                              respond_to?: true)

        expect(job.send(:should_warm_cache?, notification)).to be false
      end

      it 'returns false for notification without cache key support' do
        record = double('record', present?: true) # rubocop:todo RSpec/VerifiedDoubles
        event = double('event', record: record) # rubocop:todo RSpec/VerifiedDoubles
        notification = double('notification', # rubocop:todo RSpec/VerifiedDoubles
                              event: event,
                              created_at: 1.day.ago,
                              respond_to?: false)

        expect(job.send(:should_warm_cache?, notification)).to be false
      end

      it 'returns false for old notifications' do
        record = double('record', present?: true) # rubocop:todo RSpec/VerifiedDoubles
        event = double('event', record: record) # rubocop:todo RSpec/VerifiedDoubles
        notification = double('notification', # rubocop:todo RSpec/VerifiedDoubles
                              event: event,
                              created_at: 2.weeks.ago,
                              respond_to?: true)

        expect(job.send(:should_warm_cache?, notification)).to be false
      end
    end

    describe 'cache key methods' do
      let(:job) { described_class.new }
      # rubocop:todo RSpec/VerifiedDoubles
      let(:record) { double('record', cache_key_with_version: 'record-key', respond_to?: true) }
      # rubocop:enable RSpec/VerifiedDoubles
      # rubocop:todo RSpec/VerifiedDoubles
      let(:event) { double('event', cache_key_with_version: 'event-key', respond_to?: true, record: record) }
      # rubocop:enable RSpec/VerifiedDoubles
      let(:notification) do
        double('notification', # rubocop:todo RSpec/VerifiedDoubles
               cache_key_with_version: 'notification-key',
               event: event)
      end

      describe '#notification_fragment_cache_key' do
        it 'builds complete cache key' do
          key = job.send(:notification_fragment_cache_key, notification)

          expect(key).to include('notification-key')
          expect(key).to include('record-key')
          expect(key).to include('event-key')
          expect(key).to include(I18n.locale)
        end
      end

      describe '#notification_type_fragment_cache_key' do
        it 'builds type-specific cache key' do
          notification = double('notification', # rubocop:todo RSpec/VerifiedDoubles
                                cache_key_with_version: 'notification-key',
                                type: 'TestType',
                                event: event)

          key = job.send(:notification_type_fragment_cache_key, notification)

          expect(key).to include('TestType')
          expect(key).to include('notification-key')
          expect(key).to include(I18n.locale)
          expect(key).to include('record-key')
        end
      end
    end

    describe 'job enqueuing' do
      it 'can be enqueued with notification ids' do
        expect do
          described_class.perform_later([1, 2, 3])
        end.to have_enqueued_job(described_class).with([1, 2, 3])
      end
    end
  end
end
