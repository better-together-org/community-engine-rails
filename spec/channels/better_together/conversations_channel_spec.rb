# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ConversationsChannel do
  let(:participant) { create(:person) }
  let(:non_participant) { create(:person) }
  let(:conversation) { create(:conversation, creator: participant) }

  describe '#subscribed' do
    context 'when the user is a conversation participant' do
      before do
        stub_connection(current_person: participant)
      end

      it 'confirms the subscription' do
        subscribe(id: conversation.id)
        expect(subscription).to be_confirmed
      end

      it 'streams for the conversation' do
        subscribe(id: conversation.id)
        expect(subscription).to have_stream_for(conversation)
      end
    end

    context 'when the user is NOT a conversation participant' do
      before do
        stub_connection(current_person: non_participant)
      end

      it 'rejects the subscription' do
        subscribe(id: conversation.id)
        expect(subscription).to be_rejected
      end
    end
  end

  describe '#unsubscribed' do
    before do
      stub_connection(current_person: participant)
    end

    it 'does not raise on unsubscribe' do
      subscribe(id: conversation.id)
      expect { unsubscribe }.not_to raise_error
    end
  end
end
