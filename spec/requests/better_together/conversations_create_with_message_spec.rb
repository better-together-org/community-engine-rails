# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Create Conversation with initial message' do
  include RequestSpecHelper

  before do
    configure_host_platform
    # Ensure the test user exists and is confirmed
    unless BetterTogether::User.find_by(email: 'user@example.test')
      create(:user, :confirmed, email: 'user@example.test',
                                password: 'password12345')
    end
    login('user@example.test', 'password12345')
  end

  # rubocop:todo RSpec/MultipleExpectations
  it 'creates conversation and nested message with sender set' do # rubocop:todo RSpec/MultipleExpectations
    # rubocop:enable RSpec/MultipleExpectations
    user = BetterTogether::User.find_by(email: 'user@example.test')
    person = user.person || create(:better_together_person, user: user)

    post better_together.conversations_path(locale: I18n.default_locale), params: {
      conversation: {
        title: 'Hello',
        participant_ids: [person.id],
        messages_attributes: [{ content: 'First message' }]
      }
    }

    expect(response).to redirect_to(/conversations/)

    conv = BetterTogether::Conversation.order(:created_at).last
    expect(conv).to be_present
    expect(conv.messages.count).to eq(1)
    msg = conv.messages.first
    expect(msg.content.to_s).to include('First message')
    expect(msg.sender).to eq(user.person)
  end
end
