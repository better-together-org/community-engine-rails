# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ConversationsChannel, type: :channel do
  let(:conversation) { create(:conversation) }

  before do
    stub_connection
    allow(BetterTogether::Conversation).to receive(:find).and_return(conversation)
  end

  it 'streams for the conversation on subscribe' do
    subscribe(id: conversation.id)
    expect(subscription).to be_confirmed
  end

  it 'does not raise on unsubscribe' do
    subscribe(id: conversation.id)
    expect { unsubscribe }.not_to raise_error
  end
end
