# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/conversations/_conversation_content' do
  let(:conversation) { create(:conversation) }
  let(:messages) { [conversation.messages.first] }
  let(:message) { BetterTogether::Message.new(conversation: conversation, sender: conversation.creator) }
  let(:policy) { double('ConversationPolicy', update?: false, leave_conversation?: false) } # rubocop:todo RSpec/VerifiedDoubles

  before do
    assign(:conversation, conversation)
    allow(view).to receive(:policy).and_return(policy)
    allow(view).to receive_messages(current_person: conversation.creator, conversations_path: '/conversations')
    allow(view).to receive(:turbo_stream_from).with(conversation).and_return('')
    allow(view).to receive(:render).and_call_original
    allow(view).to receive(:render)
      .with(hash_including(partial: 'better_together/people/mention'))
      .and_return('')
    allow(view).to receive(:render)
      .with(hash_including(partial: 'better_together/messages/message'))
      .and_return('')
    allow(view).to receive(:render)
      .with(hash_including(partial: 'better_together/conversations/empty'))
      .and_return('')
    allow(view).to receive(:render)
      .with(hash_including(partial: 'better_together/messages/form'))
      .and_return('')
    allow(view).to receive(:render)
      .with('form', conversation: conversation)
      .and_return('')
  end

  def render_partial
    render partial: 'better_together/conversations/conversation_content',
           locals: { conversation: conversation, messages: messages, message: message }
  end

  it 'renders the conversation content' do
    render_partial

    expect(rendered).to include('card-footer')
  end
end
