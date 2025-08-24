# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::NotificationReadable do # rubocop:todo RSpec/SpecFilePathFormat
  let(:recipient) { create(:better_together_person) }

  let(:concern_host) do
    Class.new do
      include BetterTogether::NotificationReadable
    end.new
  end

  describe '#mark_match_notifications_read_for' do
    # rubocop:todo RSpec/MultipleExpectations
    it 'marks unread match notifications for the given record as read' do # rubocop:todo RSpec/ExampleLength, RSpec/MultipleExpectations
      # rubocop:enable RSpec/MultipleExpectations
      offer = create(:better_together_joatu_offer)
      request = create(:better_together_joatu_request)

      BetterTogether::Joatu::MatchNotifier.with(offer:, request:).deliver(recipient)

      unread_before = recipient.notifications.unread.joins(:event)
                               .where(noticed_events: { type: 'BetterTogether::Joatu::MatchNotifier' }).count
      expect(unread_before).to be >= 1

      concern_host.mark_match_notifications_read_for(offer, recipient:)

      unread_after = recipient.notifications.unread.joins(:event)
                              .where(noticed_events: { type: 'BetterTogether::Joatu::MatchNotifier' }).count
      expect(unread_after).to eq(0)
    end
  end

  describe '#mark_notifications_read_for_record' do
    # rubocop:todo RSpec/MultipleExpectations
    it 'marks unread notifications tied to the event record as read' do # rubocop:todo RSpec/ExampleLength, RSpec/MultipleExpectations
      # rubocop:enable RSpec/MultipleExpectations
      conversation = create(:better_together_conversation)
      create(:better_together_user, person: recipient)
      # Ensure recipient is a participant in the conversation to be notified
      conversation.participants << recipient unless conversation.participants.include?(recipient)

      message = conversation.messages.create!(sender: recipient, content: 'Hi there')
      BetterTogether::NewMessageNotifier.with(record: message, conversation_id: conversation.id).deliver(recipient)

      unread_before = recipient.notifications.unread.joins(:event)
                               .where(noticed_events: { type: 'BetterTogether::NewMessageNotifier' }).count
      expect(unread_before).to be >= 1

      concern_host.mark_notifications_read_for_record(message, recipient:)

      unread_after = recipient.notifications.unread.joins(:event)
                              .where(noticed_events: { type: 'BetterTogether::NewMessageNotifier' }).count
      expect(unread_after).to eq(0)
    end
  end
end
