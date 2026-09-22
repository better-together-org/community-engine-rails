# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::BotDefense::ChallengePolicy do
  subject(:policy) { described_class.new(user, :challenge) }

  describe '#show?' do
    context 'as an unauthenticated guest' do
      let(:user) { nil }

      it 'permits show — challenge issuance is a public endpoint' do
        expect(policy.show?).to be(true)
      end
    end

    context 'as an authenticated user' do
      let(:user) { create(:better_together_user) }

      it 'permits show' do
        expect(policy.show?).to be(true)
      end
    end
  end
end
