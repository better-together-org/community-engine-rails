# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Joatu::ResponseLinkPolicy do # rubocop:todo RSpec/MultipleMemoizedHelpers
  subject(:policy) { described_class.new(user, response_link) }

  let(:creator)  { create(:better_together_user, person: create(:better_together_person)) }
  let(:stranger) { create(:better_together_user, person: create(:better_together_person)) }
  let(:manager)  { create(:better_together_user, :platform_manager) }

  let(:offer) do
    create(:better_together_joatu_offer, creator: creator.person)
  end
  let(:request_record) do
    create(:better_together_joatu_request)
  end
  let(:response_link) do
    BetterTogether::Joatu::ResponseLink.new(
      source: offer,
      response: request_record,
      creator_id: creator.person.id
    )
  end

  describe '#create?' do
    context 'as an authenticated user' do
      let(:user) { creator }

      it { expect(policy.create?).to be(true) }
    end

    context 'as a guest' do
      let(:user) { nil }

      it { expect(policy.create?).to be(false) }
    end
  end

  describe '#show?' do
    context 'as the creator' do
      let(:user) { creator }

      it { expect(policy.show?).to be(true) }
    end

    context 'as an unrelated user' do
      let(:user) { stranger }

      it { expect(policy.show?).to be(false) }
    end

    context 'as a platform manager' do
      let(:user) { manager }

      it { expect(policy.show?).to be(true) }
    end

    context 'as a guest' do
      let(:user) { nil }

      it { expect(policy.show?).to be(false) }
    end
  end

  describe '#destroy?' do
    context 'as a platform manager' do
      let(:user) { manager }

      it { expect(policy.destroy?).to be(true) }
    end

    context 'as the creator (non-manager)' do
      let(:user) { creator }

      it { expect(policy.destroy?).to be(false) }
    end

    context 'as a guest' do
      let(:user) { nil }

      it { expect(policy.destroy?).to be(false) }
    end
  end

  describe 'Scope#resolve' do
    subject(:scope) { described_class::Scope.new(user, BetterTogether::Joatu::ResponseLink).resolve }

    context 'as a guest' do
      let(:user) { nil }

      it 'returns none' do
        expect(scope).to eq(BetterTogether::Joatu::ResponseLink.none)
      end
    end

    context 'as an authenticated user' do
      let(:user) { creator }

      it 'returns a relation' do
        expect(scope).to be_a(ActiveRecord::Relation)
      end
    end

    context 'as a platform manager' do
      let(:user) { manager }

      it 'returns a platform-scoped relation' do
        expect(scope).to be_a(ActiveRecord::Relation)
      end
    end
  end
end
