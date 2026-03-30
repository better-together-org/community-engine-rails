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
             current_user_person_id: conversation.creator.id,
             form_action_url: "/conversations/#{conversation.id}/messages"
           }
  end

  it 'renders the non-E2EE message form when the feature flag is disabled' do
    allow(BetterTogether).to receive(:e2ee_messaging_enabled?).and_return(false)

    render_form

    expect(rendered).to include('data-controller="better_together--message-form"')
    expect(rendered).not_to include('better-together--e2e-message-form')
    expect(rendered).not_to include('data-better-together--e2e-message-form-target="status"')
  end

  it 'adds E2EE form wiring when the feature flag is enabled' do
    allow(BetterTogether).to receive(:e2ee_messaging_enabled?).and_return(true)

    render_form

    expect(rendered).to include('data-controller="better_together--message-form better-together--e2e-message-form"')
    expect(rendered).to include(%(data-better-together--e2e-message-form-conversation-id-value="#{conversation.id}"))
    expect(rendered).to include('data-better-together--e2e-message-form-target="status"')
  end
end
