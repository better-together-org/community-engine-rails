# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe NotificationCacheManagement do
    describe 'concern functionality' do
      let(:notification) { build(:noticed_notification) }

      before do
        # Extend the notification with the concern for testing
        notification.extend(described_class)
      end

      describe '#should_expire_caches?' do
        it 'returns true when read_at changes' do
          allow(notification).to receive_messages(saved_change_to_read_at?: true, saved_change_to_created_at?: false,
                                                  saved_change_to_updated_at?: false)

          expect(notification.send(:should_expire_caches?)).to be true
        end

        it 'returns true when created_at changes' do
          allow(notification).to receive_messages(saved_change_to_read_at?: false, saved_change_to_created_at?: true,
                                                  saved_change_to_updated_at?: false)

          expect(notification.send(:should_expire_caches?)).to be true
        end

        it 'returns true when updated_at changes' do
          allow(notification).to receive_messages(saved_change_to_read_at?: false, saved_change_to_created_at?: false,
                                                  saved_change_to_updated_at?: true)

          expect(notification.send(:should_expire_caches?)).to be true
        end

        it 'returns false when nothing relevant changes' do
          allow(notification).to receive_messages(saved_change_to_read_at?: false, saved_change_to_created_at?: false,
                                                  saved_change_to_updated_at?: false)

          expect(notification.send(:should_expire_caches?)).to be false
        end
      end

      describe '#respond_to_cache_methods?' do
        it 'returns true when helper methods are available' do
          mock_helpers = double('helpers') # rubocop:todo RSpec/VerifiedDoubles
          allow(ApplicationController).to receive(:helpers).and_return(mock_helpers)
          allow(mock_helpers).to receive(:respond_to?).with(:expire_notification_fragments).and_return(true)

          expect(notification.send(:respond_to_cache_methods?)).to be true
        end

        it 'returns false when helper methods are not available' do
          mock_helpers = double('helpers') # rubocop:todo RSpec/VerifiedDoubles
          allow(ApplicationController).to receive(:helpers).and_return(mock_helpers)
          allow(mock_helpers).to receive(:respond_to?).with(:expire_notification_fragments).and_return(false)

          expect(notification.send(:respond_to_cache_methods?)).to be false
        end

        it 'returns false when helpers raise an error' do
          allow(ApplicationController).to receive(:helpers).and_raise(StandardError.new('test error'))

          expect(notification.send(:respond_to_cache_methods?)).to be false
        end
      end

      describe '#expire_notification_caches' do
        it 'calls helper methods when available' do
          mock_helpers = double('helpers') # rubocop:todo RSpec/VerifiedDoubles
          allow(ApplicationController).to receive(:helpers).and_return(mock_helpers)
          allow(mock_helpers).to receive(:respond_to?).with(:expire_notification_fragments).and_return(true)
          allow(mock_helpers).to receive(:expire_notification_fragments)

          expect(mock_helpers).to receive(:expire_notification_fragments).with(notification)
          notification.send(:expire_notification_caches)
        end

        it 'handles missing helper methods gracefully' do
          mock_helpers = double('helpers') # rubocop:todo RSpec/VerifiedDoubles
          allow(ApplicationController).to receive(:helpers).and_return(mock_helpers)
          allow(mock_helpers).to receive(:respond_to?).with(:expire_notification_fragments).and_return(false)

          expect { notification.send(:expire_notification_caches) }.not_to raise_error
        end

        it 'handles errors gracefully' do
          allow(ApplicationController).to receive(:helpers).and_raise(StandardError.new('test error'))

          expect { notification.send(:expire_notification_caches) }.not_to raise_error
        end
      end
    end
  end
end
