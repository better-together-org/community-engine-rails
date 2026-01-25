# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
module BetterTogether
  RSpec.describe JoatuMailer do
    describe 'new_match' do
      let!(:host_platform) { create(:platform, :host) }
      let(:recipient_user) { create(:user) }
      let(:offer_user) { create(:user) }
      let(:request_user) { create(:user) }
      let(:offer) { create(:better_together_joatu_offer, creator: offer_user.person) }
      let(:request) { create(:better_together_joatu_request, creator: request_user.person) }

      let(:mail) { described_class.new_match(recipient_user.person, offer:, request:) }

      it 'renders the headers' do # rubocop:todo RSpec/MultipleExpectations
        expect(mail.subject).to eq('New Joatu match')
        expect(mail.to).to include(recipient_user.email)
      end
    end

    describe 'agreement_created' do
      let!(:host_platform) { create(:platform, :host) }
      let(:offer_user) { create(:user) }
      let(:request_user) { create(:user) }
      let(:offer) { create(:joatu_offer, creator: offer_user.person) }
      let(:request) { create(:joatu_request, creator: request_user.person) }
      let(:agreement) { create(:joatu_agreement, offer:, request:) }
      let(:recipient) { offer_user.person }

      let(:mail) do
        described_class.with(agreement: agreement, recipient: recipient).agreement_created
      end

      it 'renders the headers' do # rubocop:todo RSpec/MultipleExpectations
        expect(mail.subject).to have_content('agreement was created')
        expect(mail.to).to include(offer_user.email)
        expect(mail.from).to include('community@bettertogethersolutions.com')
      end

      it 'renders the body' do # rubocop:todo RSpec/MultipleExpectations
        expect_mail_html_content(mail, offer.name)
        expect_mail_html_content(mail, request.name)
      end

      # rubocop:todo RSpec/MultipleExpectations
      it 'sends the email' do # rubocop:todo RSpec/MultipleExpectations
        # rubocop:enable RSpec/MultipleExpectations
        expect { mail.deliver_now }
          .to change { ActionMailer::Base.deliveries.count }.by(1)
        expect_mail_html_contents(mail, recipient.name, offer.name, request.name)
      end

      it 'sends the agreement created email to the recipient' do # rubocop:todo RSpec/MultipleExpectations
        expect { mail.deliver_now }.to change { ActionMailer::Base.deliveries.count }.by(1)
        expect(ActionMailer::Base.deliveries.last.to).to include(offer_user.email)
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
