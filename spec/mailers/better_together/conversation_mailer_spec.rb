# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe ConversationMailer, type: :mailer do
    describe 'new_message_notification' do
      let!(:host_platform) { create(:platform, :host) }
      let(:sender) { create(:user) }
      let(:recipient) { create(:user) }
      let(:conversation) { create(:conversation, creator: sender.person) }
      let(:message) { create(:message, conversation: conversation, sender: sender.person) }

      let(:mail) do
        ConversationMailer.with(message: message, recipient: recipient.person)
                          .new_message_notification
      end

      it 'renders the headers' do
        expect(mail.subject).to eq("[#{host_platform.name}] New message in conversation \"#{conversation.title}\"")
        expect(mail.to).to eq([recipient.email])
        expect(mail.from).to eq(['community@bettertogethersolutions.com'])
      end

      it 'renders the body' do
        expect(mail.body.encoded).to have_content("Hello #{recipient.person.name}")
        expect(mail.body.encoded).to have_content("#{sender.person.name}:")
        expect(mail.body.encoded).to have_content(message.content.to_plain_text)
      end
    end
  end
end
