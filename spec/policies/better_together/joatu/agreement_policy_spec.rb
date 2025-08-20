# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Joatu::AgreementPolicy, type: :policy do # rubocop:todo RSpec/MultipleMemoizedHelpers
  let(:offer_creator)   { create(:better_together_person) }
  let(:request_creator) { create(:better_together_person) }

  let(:offer_creator_user)   { create(:better_together_user, person: offer_creator) }
  let(:request_creator_user) { create(:better_together_user, person: request_creator) }
  let(:manager_user)         { create(:better_together_user, :platform_manager) }
  let(:normal_user)          { create(:better_together_user) }

  let(:offer)   { create(:better_together_joatu_offer, creator: offer_creator) }
  let(:request) { create(:better_together_joatu_request, creator: request_creator) }
  let(:agreement) { BetterTogether::Joatu::Agreement.create!(offer:, request:, terms: 't', value: 1) }

  describe '#show?' do # rubocop:todo RSpec/MultipleMemoizedHelpers
    it 'allows participants' do # rubocop:todo RSpec/MultipleExpectations
      expect(described_class.new(offer_creator_user, agreement).show?).to be true
      expect(described_class.new(request_creator_user, agreement).show?).to be true
    end

    it 'allows manager' do
      expect(described_class.new(manager_user, agreement).show?).to be true
    end

    it 'denies others' do # rubocop:todo RSpec/MultipleExpectations
      expect(described_class.new(normal_user, agreement).show?).to be false
      expect(described_class.new(nil, agreement).show?).to be false
    end
  end

  describe '#update?/accept?/reject?' do # rubocop:todo RSpec/MultipleMemoizedHelpers
    it 'allows participants and manager' do # rubocop:todo RSpec/MultipleExpectations
      expect(described_class.new(offer_creator_user, agreement).update?).to be true
      expect(described_class.new(request_creator_user, agreement).accept?).to be true
      expect(described_class.new(manager_user, agreement).reject?).to be true
    end

    it 'denies others' do
      expect(described_class.new(normal_user, agreement).update?).to be false
    end
  end

  describe 'Scope' do # rubocop:todo RSpec/MultipleMemoizedHelpers
    subject(:resolved) { described_class::Scope.new(user, BetterTogether::Joatu::Agreement).resolve }

    let!(:agreement1) { agreement } # rubocop:todo RSpec/IndexedLet
    let!(:agreement2) do # rubocop:todo RSpec/IndexedLet
      other_offer = create(:better_together_joatu_offer)
      other_request = create(:better_together_joatu_request)
      BetterTogether::Joatu::Agreement.create!(offer: other_offer, request: other_request, terms: 'x', value: 2)
    end

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'offer creator user' do # rubocop:todo RSpec/ContextWording, RSpec/MultipleMemoizedHelpers
      let(:user) { offer_creator_user }

      it 'includes agreements where user is a participant' do # rubocop:todo RSpec/MultipleExpectations
        expect(resolved).to include(agreement1)
        expect(resolved).not_to include(agreement2)
      end
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'manager' do # rubocop:todo RSpec/ContextWording, RSpec/MultipleMemoizedHelpers
      let(:user) { manager_user }

      it 'includes all' do
        expect(resolved).to include(agreement1, agreement2)
      end
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'guest' do # rubocop:todo RSpec/ContextWording, RSpec/MultipleMemoizedHelpers
      let(:user) { nil }

      it 'returns none' do
        expect(resolved).to be_empty
      end
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers
  end
end
