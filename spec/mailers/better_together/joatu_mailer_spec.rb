# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe JoatuMailer, type: :mailer do
    describe 'new_match' do
      let!(:host_platform) { create(:platform, :host) }
      let(:recipient_user) { create(:user) }
      let(:offer_user) { create(:user) }
      let(:request_user) { create(:user) }
      let(:offer) { create(:better_together_joatu_offer, creator: offer_user.person) }
      let(:request) { create(:better_together_joatu_request, creator: request_user.person) }

      let(:mail) { described_class.new_match(recipient_user.person, offer:, request:) }

      it 'renders the headers' do
        expect(mail.subject).to eq('New Joatu match')
        expect(mail.to).to include(recipient_user.email)
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
        JoatuMailer.with(agreement: agreement, recipient: recipient).agreement_created
      end

      it 'renders the headers' do
        expect(mail.subject).to have_content('agreement was created')
        expect(mail.to).to include(offer_user.email)
        expect(mail.from).to include('community@bettertogethersolutions.com')
      end

      it 'renders the body' do
        expect(mail.body.encoded).to include(offer.name)
        expect(mail.body.encoded).to include(request.name)
      end

      it 'sends the email' do
        expect { mail.deliver_now }
          .to change { ActionMailer::Base.deliveries.count }.by(1)
        expect(mail.body.encoded).to have_content("Hello #{recipient.name}")
        expect(mail.body.encoded).to have_content(
          "An agreement has been created between \"#{offer.name}\" and \"#{request.name}\""
        )
      end

      it 'sends the agreement created email to the recipient' do
        expect { mail.deliver_now }.to change { ActionMailer::Base.deliveries.count }.by(1)
        expect(ActionMailer::Base.deliveries.last.to).to include(offer_user.email)
      end
    end
  end
end
