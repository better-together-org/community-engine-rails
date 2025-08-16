# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Joatu
    RSpec.describe AgreementNotifier do
      let(:offer_user) { create(:user) }
      let(:request_user) { create(:user) }
      let(:offer) { create(:joatu_offer, creator: offer_user.person) }
      let(:request) { create(:joatu_request, creator: request_user.person) }

      it 'notifies both offer and request creators when agreement is created' do
        expect do
          create(:joatu_agreement, offer:, request:)
        end.to change(Noticed::Notification, :count).by(2)

        recipients = Noticed::Notification.last(2).map(&:recipient)
        expect(recipients).to contain_exactly(offer_user.person, request_user.person)
      end

      it 'builds message with offer and request names' do
        agreement = build(:joatu_agreement, offer:, request:)
        notifier = described_class.new(record: agreement)

        expect(notifier.title).to eq(
          I18n.t('better_together.notifications.joatu.agreement_created.title')
        )
        expect(notifier.body).to eq(
          I18n.t('better_together.notifications.joatu.agreement_created.content',
                 offer: offer.name,
                 request: request.name)
        )
      end
    end
  end
end
