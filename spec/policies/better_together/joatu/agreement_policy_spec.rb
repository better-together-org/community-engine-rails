# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Joatu::AgreementPolicy, type: :policy do
  let(:offer_creator)   { create(:better_together_person) }
  let(:request_creator) { create(:better_together_person) }

  let(:offer_creator_user)   { create(:better_together_user, person: offer_creator) }
  let(:request_creator_user) { create(:better_together_user, person: request_creator) }
  let(:manager_user)         { create(:better_together_user, :platform_manager) }
  let(:normal_user)          { create(:better_together_user) }

  let(:offer)   { create(:better_together_joatu_offer, creator: offer_creator) }
  let(:request) { create(:better_together_joatu_request, creator: request_creator) }
  let(:agreement) { BetterTogether::Joatu::Agreement.create!(offer:, request:, terms: 't', value: 1) }

  describe '#show?' do
    it 'allows participants' do
      expect(described_class.new(offer_creator_user, agreement).show?).to eq true
      expect(described_class.new(request_creator_user, agreement).show?).to eq true
    end
    it 'allows manager' do
      expect(described_class.new(manager_user, agreement).show?).to eq true
    end
    it 'denies others' do
      expect(described_class.new(normal_user, agreement).show?).to eq false
      expect(described_class.new(nil, agreement).show?).to eq false
    end
  end

  describe '#update?/accept?/reject?' do
    it 'allows participants and manager' do
      expect(described_class.new(offer_creator_user, agreement).update?).to eq true
      expect(described_class.new(request_creator_user, agreement).accept?).to eq true
      expect(described_class.new(manager_user, agreement).reject?).to eq true
    end
    it 'denies others' do
      expect(described_class.new(normal_user, agreement).update?).to eq false
    end
  end

  describe 'Scope' do
    subject(:resolved) { described_class::Scope.new(user, BetterTogether::Joatu::Agreement).resolve }

    let!(:agreement1) { agreement }
    let!(:agreement2) do
      other_offer = create(:better_together_joatu_offer)
      other_request = create(:better_together_joatu_request)
      BetterTogether::Joatu::Agreement.create!(offer: other_offer, request: other_request, terms: 'x', value: 2)
    end

    context 'offer creator user' do
      let(:user) { offer_creator_user }
      it 'includes agreements where user is a participant' do
        expect(resolved).to include(agreement1)
        expect(resolved).not_to include(agreement2)
      end
    end

    context 'manager' do
      let(:user) { manager_user }
      it 'includes all' do
        expect(resolved).to include(agreement1, agreement2)
      end
    end

    context 'guest' do
      let(:user) { nil }
      it 'returns none' do
        expect(resolved).to be_empty
      end
    end
  end
end

