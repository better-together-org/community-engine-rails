# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::EventAttendancePolicy, type: :policy do
  let(:event_creator) { create(:better_together_person) }
  let(:other_person) { create(:better_together_person) }
  let(:creator_user)   { create(:better_together_user, person: event_creator) }
  let(:other_user) { create(:better_together_user, person: other_person) }
  let(:event) { BetterTogether::Event.create!(name: 'Policy Event', starts_at: 1.day.from_now, identifier: SecureRandom.uuid) }

  describe '#create?' do
    it 'permits any logged in user' do
      policy = described_class.new(creator_user, BetterTogether::EventAttendance.new(event:, person: event_creator))
      expect(policy.create?).to be true
    end

    it 'denies guests' do
      policy = described_class.new(nil, BetterTogether::EventAttendance.new(event:, person: event_creator))
      expect(policy.create?).to be false
    end
  end

  describe '#update?/#destroy?' do
    it 'permits the owner' do
      record = BetterTogether::EventAttendance.new(event:, person: event_creator, status: 'interested')
      policy = described_class.new(creator_user, record)

      expect(policy.update?).to be true
    end

    it 'allows owner to destroy their attendance' do
      record = BetterTogether::EventAttendance.new(event:, person: event_creator, status: 'interested')
      policy = described_class.new(creator_user, record)

      expect(policy.destroy?).to be true
    end

    it 'denies other users from updating' do
      record = BetterTogether::EventAttendance.new(event:, person: event_creator, status: 'going')
      policy = described_class.new(other_user, record)

      expect(policy.update?).to be false
    end

    it 'denies other users from destroying' do
      record = BetterTogether::EventAttendance.new(event:, person: event_creator, status: 'going')
      policy = described_class.new(other_user, record)

      expect(policy.destroy?).to be false
    end
  end
end
