# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/messages/_form' do
  let(:conversation) { create(:conversation) }
  let(:message) { BetterTogether::Message.new(conversation: conversation, sender: conversation.creator) }

  def render_form
    render partial: 'better_together/messages/form',
           locals: {
             conversation: conversation,
             message: message,
             form_action_url: "/conversations/#{conversation.id}/messages"
           }
  end

  it 'renders the message form' do
    render_form

    expect(rendered).to include('data-controller="better_together--message-form"')
    expect(rendered).not_to include('disabled="disabled"')
  end
end
