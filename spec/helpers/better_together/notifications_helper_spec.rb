# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
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
  end
  # rubocop:enable Metrics/BlockLength
end
