# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Conversation message protection', type: :request do
  include RequestSpecHelper

  it "prevents a user from altering another user's message via conversation update" do
  # Setup: ensure host platform exists and create users with known passwords
  configure_host_platform
    
    # Setup: create a manager user (owner of the conversation) and another user
  manager_user = create(:user, :confirmed, :platform_manager, email: 'owner@example.test', password: 'password12345')
  other_user = create(:user, :confirmed, email: 'attacker@example.test', password: 'password12345')

    # Create a conversation as the manager with a nested message
  login(manager_user.email, 'password12345')

    post better_together.conversations_path(locale: I18n.default_locale), params: {
      conversation: {
        title: 'Protected convo',
        participant_ids: [manager_user.person.id, other_user.person.id],
        messages_attributes: [
          { content: 'Original message' }
        ]
      }
    }

    expect(response).to have_http_status(:found)
    conversation = BetterTogether::Conversation.order(created_at: :desc).first
    message = conversation.messages.first
    expect(message.content.to_plain_text).to include('Original message')

    # Now sign in as other_user and attempt to change manager's message via PATCH
  logout
  login(other_user.email, 'password12345')

    patch better_together.conversation_path(conversation, locale: I18n.default_locale), params: {
      conversation: {
        title: conversation.title,
        messages_attributes: [
          { id: message.id, content: 'Tampered message', sender_id: other_user.person.id }
        ]
      }
    }

    # Reload message and assert it was not changed
    message.reload
    expect(message.content.to_plain_text).to include('Original message')
  end
end
