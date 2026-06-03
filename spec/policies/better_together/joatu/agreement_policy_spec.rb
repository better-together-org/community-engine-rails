# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Joatu::AgreementPolicy do
  subject(:policy) { described_class.new(user, agreement) }

  let(:offer_creator) { create(:better_together_user, person: create(:better_together_person)) }
  let(:request_creator) { create(:better_together_user, person: create(:better_together_person)) }
  let(:network_admin) { create(:better_together_user, :network_admin) }
  let(:stranger) { create(:better_together_user, person: create(:better_together_person)) }

  let(:agreement) do
    create(:better_together_joatu_agreement,
           privacy: 'private',
           offer: create(:better_together_joatu_offer, creator: offer_creator.person),
           request: create(:better_together_joatu_request, creator: request_creator.person))
  end
  let(:connection_agreement) do
    create(:better_together_joatu_agreement,
           offer: create(:better_together_joatu_offer, creator: offer_creator.person, target: create(:better_together_platform)),
           request: create(:better_together_joatu_connection_request, creator: request_creator.person,
                                                                      target: create(:better_together_platform)))
  end

  context 'as offer creator' do
    let(:user) { offer_creator }

    it 'permits participant actions' do
      expect(policy.show?).to be(true)
      expect(policy.create?).to be(true)
      expect(policy.update?).to be(true)
      expect(policy.accept?).to be(true)
      expect(policy.reject?).to be(true)
      expect(policy.destroy?).to be(true)
    end
  end

  context 'as request creator' do
    let(:user) { request_creator }

    it 'permits participant actions' do
      expect(policy.show?).to be(true)
      expect(policy.create?).to be(true)
      expect(policy.update?).to be(true)
      expect(policy.accept?).to be(true)
      expect(policy.reject?).to be(true)
      expect(policy.destroy?).to be(true)
    end
  end

  context 'as unrelated user' do
    let(:user) { stranger }

    it 'forbids participant actions' do
      expect(policy.show?).to be(false)
      expect(policy.create?).to be(false)
      expect(policy.update?).to be(false)
      expect(policy.accept?).to be(false)
      expect(policy.reject?).to be(false)
      expect(policy.destroy?).to be(false)
    end

    it 'allows viewing a public agreement' do
      agreement.update_column(:privacy, 'public')
      expect(policy.show?).to be(true)
    end
  end

  context 'for a connection agreement' do
    context 'as a participant without network permissions' do
      let(:user) { offer_creator }
      let(:agreement) { connection_agreement }

      it 'allows view but forbids create, update, accept, reject, and destroy' do
        expect(policy.show?).to be(true)
        expect(policy.create?).to be(false)
        expect(policy.update?).to be(false)
        expect(policy.accept?).to be(false)
        expect(policy.reject?).to be(false)
        expect(policy.destroy?).to be(false)
      end
    end

    context 'as network admin' do
      let(:user) { network_admin }
      let(:agreement) { connection_agreement }

      it 'permits network management and approval actions' do
        expect(policy.show?).to be(true)
        expect(policy.create?).to be(true)
        expect(policy.update?).to be(true)
        expect(policy.accept?).to be(true)
        expect(policy.reject?).to be(true)
        expect(policy.destroy?).to be(true)
      end
    end
  end
end
