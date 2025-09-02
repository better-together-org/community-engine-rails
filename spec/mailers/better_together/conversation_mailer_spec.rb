# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe ConversationMailer do
    describe 'new_message_notification' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      let!(:host_platform) { create(:platform, :host) } # rubocop:todo RSpec/LetSetup
      let(:sender) { create(:user) }
      let(:recipient) { create(:user) }
      let(:conversation) { create(:conversation, creator: sender.person) }
      let(:message) { create(:message, conversation: conversation, sender: sender.person) }

      let(:mail) do
        described_class.with(message: message, recipient: recipient.person)
                       .new_message_notification
      end

      it 'renders the headers' do # rubocop:todo RSpec/MultipleExpectations
        expect(mail.subject).to have_content('conversation has an unread message')
        expect(mail.to).to include(recipient.email)
        expect(mail.from).to include('community@bettertogethersolutions.com')
      end

      it 'renders the body' do # rubocop:todo RSpec/MultipleExpectations
        expect(mail.body.encoded).to have_content("Hello #{recipient.person.name}")
        expect(mail.body.encoded).to have_content('You have an unread message')
      end

      it 'sends a message notification email' do
        expect { mail.deliver_now }
          .to change { ActionMailer::Base.deliveries.count }.by(1)
      end

      it 'sends the message notification to the correct email address' do
        mail.deliver_now
        expect(ActionMailer::Base.deliveries.last.to).to include(recipient.email)
      end
    end
  end
end
