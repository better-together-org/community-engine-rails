# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  # rubocop:disable Metrics/BlockLength
  RSpec.describe 'Notifications', type: :request do
    include RequestSpecHelper
    include BetterTogether::DeviseSessionHelpers

    let(:user_password) { 'password12345' }
    let(:user) { create(:user, :confirmed, password: user_password) }
    let(:person) { user.person }
    let(:message_one) { create(:message) }
    let(:message_two) { create(:message) }

    before do
      configure_host_platform
      login(user)
      3.times { BetterTogether::NewMessageNotifier.with(record: message_one).deliver(person) }
      2.times { BetterTogether::NewMessageNotifier.with(record: message_two).deliver(person) }
    end

    it 'marks all notifications for the same record as read' do
      notification = person
                     .notifications
                     .joins(:event)
                     .find_by(noticed_events: { record_id: message_one.id })

      post mark_as_read_notification_path(notification, locale: I18n.default_locale)

      expect(person.notifications.joins(:event)
                        .where(noticed_events: { record_id: message_one.id })
                        .unread.count).to eq(0)
      expect(person.notifications.joins(:event)
                        .where(noticed_events: { record_id: message_two.id })
                        .unread.count).to eq(2)
    end
  end
  # rubocop:enable Metrics/BlockLength
end
