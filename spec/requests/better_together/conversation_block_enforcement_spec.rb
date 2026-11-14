# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Conversation block enforcement' do
  include RequestSpecHelper

  let(:password) { 'SecureTest123!@#' }
  let(:locale) { I18n.default_locale }
  let!(:sender) { create(:user, :confirmed, email: 'sender@example.test', password:) }
  let!(:recipient) { create(:user, :confirmed, email: 'recipient@example.test', password:) }
  let!(:conversation) do
    create(:better_together_conversation, creator: sender.person).tap do |convo|
      convo.participants << recipient.person
    end
  end

  before do
    configure_host_platform
    recipient.person.update!(preferences: recipient.person.preferences.merge('receive_messages_from_members' => true))
  end

  def post_message(content)
    post better_together.conversation_messages_path(conversation, locale:),
         params: { message: { content: } }, as: :turbo_stream
  end

  it 'lets participants message each other when no block exists' do
    login(sender.email, password)

    expect { post_message('hello') }.to change(BetterTogether::Message, :count).by(1)
  end

  it 'stops a participant messaging someone who blocked them', :aggregate_failures do
    create(:person_block, blocker: recipient.person, blocked: sender.person)
    login(sender.email, password)

    expect { post_message('still here') }.not_to change(BetterTogether::Message, :count)
  end

  it 'stops a participant messaging someone they blocked' do
    create(:person_block, blocker: sender.person, blocked: recipient.person)
    login(sender.email, password)

    expect { post_message('after my block') }.not_to change(BetterTogether::Message, :count)
  end

  it 'does not add someone who blocked the creator as a participant on new conversations', :aggregate_failures do
    create(:person_block, blocker: recipient.person, blocked: sender.person)
    login(sender.email, password)

    post better_together.conversations_path(locale:), params: {
      conversation: { title: 'Blocked invite', participant_ids: [recipient.person.id],
                      messages_attributes: [{ content: 'hi' }] }
    }

    created = BetterTogether::Conversation.find_by(title: 'Blocked invite')
    expect(created&.participants.to_a).not_to include(recipient.person)
  end
end
