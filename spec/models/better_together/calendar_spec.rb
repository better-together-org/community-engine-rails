# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe Calendar do
    describe 'subscription token' do
      let(:community) { create(:community) }
      let(:calendar) { build(:calendar, community: community) }

      describe 'automatic generation' do
        it 'generates a subscription token on creation' do
          expect(calendar.subscription_token).to be_nil
          calendar.save!
          expect(calendar.subscription_token).to be_present
          expect(calendar.subscription_token).to match(/\A[a-f0-9-]{36}\z/) # UUID format
        end

        it 'generates a unique token' do
          calendar1 = create(:calendar, community: community)
          calendar2 = create(:calendar, community: community)

          expect(calendar1.subscription_token).not_to eq(calendar2.subscription_token)
        end

        it 'validates uniqueness of subscription_token' do
          calendar1 = create(:calendar, community: community)
          calendar2 = build(:calendar, community: community, subscription_token: calendar1.subscription_token)

          expect(calendar2).not_to be_valid
          expect(calendar2.errors[:subscription_token]).to include('has already been taken')
        end
      end

      describe '#regenerate_subscription_token!' do
        it 'generates a new subscription token' do
          calendar.save!
          original_token = calendar.subscription_token

          calendar.regenerate_subscription_token!

          expect(calendar.subscription_token).not_to eq(original_token)
          expect(calendar.subscription_token).to be_present
        end

        it 'persists the new token to the database' do
          calendar.save!
          original_token = calendar.subscription_token

          calendar.regenerate_subscription_token!

          calendar.reload
          expect(calendar.subscription_token).not_to eq(original_token)
        end
      end
    end
  end
end
