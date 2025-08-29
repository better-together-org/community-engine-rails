# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Joatu::AgreementPolicy do
  subject(:policy) { described_class.new(user, agreement) }

  let(:offer_creator) { create(:better_together_user, person: create(:better_together_person)) }
  let(:request_creator) { create(:better_together_user, person: create(:better_together_person)) }
  let(:stranger) { create(:better_together_user, person: create(:better_together_person)) }

  let(:agreement) do
    create(:better_together_joatu_agreement,
           offer: create(:better_together_joatu_offer, creator: offer_creator.person),
           request: create(:better_together_joatu_request, creator: request_creator.person))
  end

  context 'as offer creator' do # rubocop:todo RSpec/ContextWording
    let(:user) { offer_creator }

    # rubocop:todo RSpec/MultipleExpectations
    it 'permits participant actions' do # rubocop:todo RSpec/ExampleLength, RSpec/MultipleExpectations
      # rubocop:enable RSpec/MultipleExpectations
      expect(policy.show?).to be(true)
      expect(policy.create?).to be(true)
      expect(policy.update?).to be(true)
      expect(policy.accept?).to be(true)
      expect(policy.reject?).to be(true)
      expect(policy.destroy?).to be(true)
    end
  end

  context 'as request creator' do # rubocop:todo RSpec/ContextWording
    let(:user) { request_creator }

    # rubocop:todo RSpec/MultipleExpectations
    it 'permits participant actions' do # rubocop:todo RSpec/ExampleLength, RSpec/MultipleExpectations
      # rubocop:enable RSpec/MultipleExpectations
      expect(policy.show?).to be(true)
      expect(policy.create?).to be(true)
      expect(policy.update?).to be(true)
      expect(policy.accept?).to be(true)
      expect(policy.reject?).to be(true)
      expect(policy.destroy?).to be(true)
    end
  end

  context 'as unrelated user' do # rubocop:todo RSpec/ContextWording
    let(:user) { stranger }

    # rubocop:todo RSpec/MultipleExpectations
    it 'forbids participant actions' do # rubocop:todo RSpec/ExampleLength, RSpec/MultipleExpectations
      # rubocop:enable RSpec/MultipleExpectations
      expect(policy.show?).to be(false)
      expect(policy.create?).to be(false)
      expect(policy.update?).to be(false)
      expect(policy.accept?).to be(false)
      expect(policy.reject?).to be(false)
      expect(policy.destroy?).to be(false)
    end
  end
end
