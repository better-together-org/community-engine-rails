# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ApplicationPolicy do
  subject(:policy) { described_class.new(user, record) }

  let(:record) { create(:better_together_platform) }
  let(:user) { nil }

  describe 'initialization' do
    context 'when user is a regular User' do
      let(:user) { create(:better_together_user) }

      it 'assigns user from the first argument' do
        expect(policy.user).to eq(user)
      end

      it 'sets agent to the user person' do
        expect(policy.agent).to eq(user.person)
      end

      it 'sets robot to nil' do
        expect(policy.robot).to be_nil
      end
    end

    context 'when a Robot is passed as user' do
      subject(:policy) { described_class.new(robot, record) }

      let(:robot) { create(:better_together_robot) }
      let(:user) { robot }

      it 'assigns robot from the first argument' do
        expect(policy.robot).to eq(robot)
      end

      it 'sets user to nil (robot is not a user)' do
        expect(policy.user).to be_nil
      end

      it 'sets agent to nil' do
        expect(policy.agent).to be_nil
      end
    end

    context 'when user is nil (unauthenticated)' do
      let(:user) { nil }

      it 'sets user, agent, and robot to nil' do
        expect(policy.user).to be_nil
        expect(policy.agent).to be_nil
        expect(policy.robot).to be_nil
      end
    end
  end

  describe 'default permission methods' do
    let(:user) { nil }

    it 'denies index? by default' do
      expect(policy.index?).to be false
    end

    it 'denies show? by default' do
      expect(policy.show?).to be false
    end

    it 'denies create? by default' do
      expect(policy.create?).to be false
    end

    it 'denies new? by default' do
      expect(policy.new?).to be false
    end

    it 'denies update? by default' do
      expect(policy.update?).to be false
    end

    it 'denies edit? by default' do
      expect(policy.edit?).to be false
    end

    it 'denies destroy? by default' do
      expect(policy.destroy?).to be false
    end
  end

  describe '#new? delegates to #create?' do
    it 'returns the same value as create?' do
      expect(policy.new?).to eq(policy.create?)
    end
  end

  describe '#edit? delegates to #update?' do
    it 'returns the same value as update?' do
      expect(policy.edit?).to eq(policy.update?)
    end
  end

  describe '#record' do
    it 'exposes the record passed to the constructor' do
      expect(policy.record).to eq(record)
    end
  end

  describe '#invitation_token' do
    subject(:policy) { described_class.new(user, record, invitation_token: 'tok-abc') }

    it 'stores the invitation token' do
      expect(policy.invitation_token).to eq('tok-abc')
    end
  end
end
