# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Joatu
    RSpec.describe MatchNotifier do
      let(:offer_user) { create(:user) }
      let(:request_user) { create(:user) }
      let(:offer) { create(:better_together_joatu_offer, creator: offer_user.person) }
      let(:request) { create(:better_together_joatu_request, creator: request_user.person) }

      subject(:notifier) { described_class.with(offer:, request:) }

      it 'builds a message including offer and request names' do
        notification = double('Notification', recipient: offer.creator)
        message = notifier.send(:build_message, notification)
        expect(message[:title]).to include('New match')
        expect(message[:body]).to include(offer.name)
        expect(message[:body]).to include(request.name)
      end

      it 'delivers an email to the offer creator' do
        expect { notifier.deliver_now(offer.creator) }
          .to change { ActionMailer::Base.deliveries.count }.by(1)
      end
    end
  end
end
