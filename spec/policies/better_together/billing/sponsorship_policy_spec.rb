# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::SponsorshipPolicy do
  subject(:policy) { described_class.new(user, sponsorship) }

  let(:sponsor_person) { create(:better_together_person) }
  let(:beneficiary_person) { create(:better_together_person, accepts_sponsorship: true) }
  let(:sponsor_user) { create(:better_together_user, :confirmed, password: 'SecureTest123!@#', person: sponsor_person) }
  let(:beneficiary_user) do
    create(:better_together_user, :confirmed, password: 'SecureTest123!@#', person: beneficiary_person)
  end
  let(:stranger_user) { create(:better_together_user, :confirmed, password: 'SecureTest123!@#') }
  let(:sponsorship) do
    create(:better_together_billing_sponsorship, sponsor: sponsor_person, beneficiary: beneficiary_person,
                                                 status: 'pending')
  end

  describe '#create?' do
    let(:user) { sponsor_user }

    it 'permits the sponsor' do
      expect(policy.create?).to be(true)
    end

    context 'when the current user is not the sponsor' do
      let(:user) { stranger_user }

      it 'denies' do
        expect(policy.create?).to be(false)
      end
    end

    context 'when unauthenticated' do
      let(:user) { nil }

      it 'denies' do
        expect(policy.create?).to be(false)
      end
    end
  end

  describe '#accept?' do
    let(:user) { beneficiary_user }

    it 'permits the beneficiary while pending' do
      expect(policy.accept?).to be(true)
    end

    it 'denies the sponsor' do
      expect(described_class.new(sponsor_user, sponsorship).accept?).to be(false)
    end

    context 'when already accepted' do
      let(:sponsorship) do
        create(:better_together_billing_sponsorship, sponsor: sponsor_person, beneficiary: beneficiary_person,
                                                     status: 'accepted')
      end

      it 'denies' do
        expect(policy.accept?).to be(false)
      end
    end
  end

  describe '#decline?' do
    let(:user) { beneficiary_user }

    it 'permits the beneficiary while pending' do
      expect(policy.decline?).to be(true)
    end
  end

  describe '#end?' do
    let(:sponsorship) do
      create(:better_together_billing_sponsorship, sponsor: sponsor_person, beneficiary: beneficiary_person,
                                                   status: 'active')
    end

    it 'permits the sponsor' do
      expect(described_class.new(sponsor_user, sponsorship).end?).to be(true)
    end

    it 'permits the beneficiary' do
      expect(described_class.new(beneficiary_user, sponsorship).end?).to be(true)
    end

    it 'denies a stranger' do
      expect(described_class.new(stranger_user, sponsorship).end?).to be(false)
    end

    context 'when the sponsorship has already ended' do
      let(:sponsorship) do
        create(:better_together_billing_sponsorship, sponsor: sponsor_person, beneficiary: beneficiary_person,
                                                     status: 'ended')
      end

      it 'denies' do
        expect(described_class.new(sponsor_user, sponsorship).end?).to be(false)
      end
    end
  end

  describe 'with a Community sponsor/beneficiary' do
    let(:sponsor_community) { create(:better_together_community) }
    let(:beneficiary_community) { create(:better_together_community, accepts_sponsorship: true) }
    let(:sponsorship) do
      create(:better_together_billing_sponsorship, sponsor: sponsor_community, beneficiary: beneficiary_community,
                                                   status: 'pending')
    end

    it 'defers to the community policy for authorization' do
      manager_user = create(:better_together_user, :confirmed, password: 'SecureTest123!@#')
      allow(Pundit).to receive(:policy!).and_call_original
      allow(Pundit).to receive(:policy!).with(anything, sponsor_community).and_return(
        instance_double(BetterTogether::CommunityPolicy, update?: true)
      )

      expect(described_class.new(manager_user, sponsorship).create?).to be(true)
    end
  end
end
