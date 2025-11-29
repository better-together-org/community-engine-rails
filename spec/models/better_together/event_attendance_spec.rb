# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe EventAttendance do
    let(:person) { create(:better_together_person) }
    let(:event) { BetterTogether::Event.create!(name: 'Test', starts_at: Time.zone.now, identifier: SecureRandom.uuid) }
    let(:attendance) { described_class.create!(event:, person:, status: 'interested') }

    it 'validates inclusion of status' do
      attendance = described_class.new(status: 'invalid_status')

      expect(attendance).not_to be_valid
    end

    it 'includes expected error for invalid status' do
      attendance = described_class.new(status: 'invalid_status')
      attendance.valid?

      expect(attendance.errors[:status]).to be_present
    end

    it 'enforces uniqueness per event/person' do
      duplicate = described_class.new(event: attendance.event, person: attendance.person)

      expect(duplicate).not_to be_valid
    end

    it 'includes uniqueness error for duplicate attendance' do
      duplicate = described_class.new(event: attendance.event, person: attendance.person)
      duplicate.valid?

      expect(duplicate.errors[:event_id]).to include('has already been taken')
    end
  end
end
