# frozen_string_literal: true

require 'rails_helper'

module BetterTogether # rubocop:todo Metrics/ModuleLength
  # rubocop:disable Metrics/BlockLength
  RSpec.describe NotificationsHelper do
    let(:unread_count) { 0 }
    let(:unread_relation) { double('unread_relation', size: unread_count) } # rubocop:todo RSpec/VerifiedDoubles
    let(:notifications) { double('notifications', unread: unread_relation) } # rubocop:todo RSpec/VerifiedDoubles
    let(:person) { double('person', notifications: notifications) } # rubocop:todo RSpec/VerifiedDoubles

    before do
      p = person
      helper.singleton_class.define_method(:current_person) { p }
    end

    describe '#unread_notification_count' do
      let(:unread_count) { 1 }

      it 'returns number of unread notifications for current person' do
        expect(helper.unread_notification_count).to eq(1)
      end

      it 'returns nil when there is no current person' do
        helper.singleton_class.define_method(:current_person) { nil }
        expect(helper.unread_notification_count).to be_nil
      end
    end

    describe '#unread_notification_counter' do
      let(:unread_count) { 2 }

      it 'renders badge html when unread notifications present' do
        html = helper.unread_notification_counter
        expect(html).to include('span')
        expect(html).to include('person_notification_count')
        expect(html).to include('badge')
      end

      it 'returns nil when there are no unread notifications' do
        no_unread = double('unread_relation', size: 0) # rubocop:todo RSpec/VerifiedDoubles
        no_notifications = double('notifications', unread: no_unread) # rubocop:todo RSpec/VerifiedDoubles
        no_person = double('person', notifications: no_notifications) # rubocop:todo RSpec/VerifiedDoubles
        helper.singleton_class.define_method(:current_person) { no_person }
        expect(helper.unread_notification_counter).to be_nil
      end
    end

    describe '#unread_notifications?' do
      let(:unread_count) { 3 }

      it 'returns true when unread notifications exist' do
        expect(helper.unread_notifications?).to be true
      end

      it 'returns false when there are no unread notifications' do
        no_unread = double('unread_relation', size: 0) # rubocop:todo RSpec/VerifiedDoubles
        no_notifications = double('notifications', unread: no_unread) # rubocop:todo RSpec/VerifiedDoubles
        no_person = double('person', notifications: no_notifications) # rubocop:todo RSpec/VerifiedDoubles
        helper.singleton_class.define_method(:current_person) { no_person }
        expect(helper.unread_notifications?).to be false
      end
    end

    describe '#recent_notifications' do
      let(:recent_notifications) { double('recent_notifications') } # rubocop:todo RSpec/VerifiedDoubles
      # rubocop:todo RSpec/VerifiedDoubles
      let(:ordered_notifications) { double('ordered_notifications', limit: recent_notifications) }
      # rubocop:enable RSpec/VerifiedDoubles
      # rubocop:todo RSpec/VerifiedDoubles
      let(:joined_notifications) { double('joined_notifications', order: ordered_notifications) }
      # rubocop:enable RSpec/VerifiedDoubles
      let(:notifications) { double('notifications', joins: joined_notifications) } # rubocop:todo RSpec/VerifiedDoubles

      it 'returns recent notifications ordered by created_at desc' do
        expect(helper.recent_notifications).to eq(recent_notifications)
      end
    end

    describe 'fragment cache methods' do
      let(:record) { double('record', cache_key_with_version: 'record-1-version') } # rubocop:todo RSpec/VerifiedDoubles
      # rubocop:todo RSpec/VerifiedDoubles
      let(:event) { double('event', cache_key_with_version: 'event-1-version', record: record) }
      # rubocop:enable RSpec/VerifiedDoubles
      let(:notification) do
        double('notification', # rubocop:todo RSpec/VerifiedDoubles
               cache_key_with_version: 'notification-1-version',
               type: 'TestNotifier',
               class: double(name: 'TestNotifierClass'), # rubocop:todo RSpec/VerifiedDoubles
               event: event)
      end

      describe '#notification_fragment_cache_key' do
        it 'builds cache key with notification, record, event and locale' do
          key = helper.notification_fragment_cache_key(notification)

          expect(key).to include('notification-1-version')
          expect(key).to include('record-1-version')
          expect(key).to include('event-1-version')
          expect(key).to include(I18n.locale)
        end

        it 'handles notification without record cache key' do
          allow(record).to receive(:respond_to?).with(:cache_key_with_version).and_return(false)

          key = helper.notification_fragment_cache_key(notification)
          expect(key).to include('notification-1-version')
          expect(key).not_to include('record-1-version')
        end

        it 'handles notification without event cache key' do
          allow(event).to receive(:respond_to?).with(:cache_key_with_version).and_return(false)

          key = helper.notification_fragment_cache_key(notification)
          expect(key).to include('notification-1-version')
          expect(key).not_to include('event-1-version')
        end
      end

      describe '#notification_type_fragment_cache_key' do
        it 'builds type-specific cache key' do
          key = helper.notification_type_fragment_cache_key(notification)

          expect(key).to include('TestNotifier')
          expect(key).to include('notification-1-version')
          expect(key).to include(I18n.locale)
          expect(key).to include('record-1-version')
        end

        it 'uses class name when type is nil' do
          allow(notification).to receive(:type).and_return(nil)

          key = helper.notification_type_fragment_cache_key(notification)
          expect(key).to include('TestNotifierClass')
        end
      end

      describe '#should_cache_notification?' do
        it 'returns true for valid notification' do
          allow(notification).to receive(:present?).and_return(true)
          allow(notification).to receive(:respond_to?).with(:cache_key_with_version).and_return(true)
          allow(record).to receive(:present?).and_return(true)

          expect(helper.should_cache_notification?(notification)).to be true
        end

        it 'returns false when notification is not present' do
          allow(notification).to receive(:present?).and_return(false)

          expect(helper.should_cache_notification?(notification)).to be false
        end

        it 'returns false when record is not present' do
          allow(notification).to receive(:present?).and_return(true)
          allow(record).to receive(:present?).and_return(false)

          expect(helper.should_cache_notification?(notification)).to be false
        end

        it 'returns false when notification does not respond to cache_key_with_version' do
          allow(notification).to receive(:present?).and_return(true)
          allow(notification).to receive(:respond_to?).with(:cache_key_with_version).and_return(false)
          allow(record).to receive(:present?).and_return(true)

          expect(helper.should_cache_notification?(notification)).to be false
        end
      end

      describe '#expire_notification_fragments' do
        it 'expires all related fragment caches' do
          # Helper specs don't have access to expire_fragment, so we define it
          helper.define_singleton_method(:expire_fragment) { |_key| true }

          expect(helper).to respond_to(:expire_notification_fragments)
          expect { helper.expire_notification_fragments(notification) }.not_to raise_error
        end
      end

      describe '#expire_notification_type_fragments' do
        it 'deletes cache entries matching notification type pattern' do
          expect(Rails.cache).to receive(:delete_matched).with('*TestNotifier*')

          helper.expire_notification_type_fragments('TestNotifier')
        end
      end
    end
  end
  # rubocop:enable Metrics/BlockLength
end
