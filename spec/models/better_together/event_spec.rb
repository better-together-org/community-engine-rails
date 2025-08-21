# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe Event do
    subject(:event) { described_class.new(name: 'Event', starts_at: Time.current) }

    it 'exists' do
      expect(described_class).to be # rubocop:todo RSpec/Be
    end

    it 'requires ends_at to be after starts_at' do # rubocop:todo RSpec/MultipleExpectations
      event.ends_at = event.starts_at - 1.hour
      expect(event).not_to be_valid
      expect(event.errors[:ends_at]).to include(I18n.t('errors.models.ends_at_before_starts_at'))
    end

    it 'is valid when ends_at is after starts_at' do
      event.ends_at = event.starts_at + 1.hour
      expect(event).to be_valid
    end

    describe 'scopes' do
      it 'returns draft events when starts_at is nil' do
        draft = described_class.create!(name: 'Draft event', starts_at: nil, identifier: SecureRandom.uuid)
        _other = described_class.create!(name: 'Other', starts_at: 1.day.from_now, identifier: SecureRandom.uuid)
        expect(described_class.draft).to include(draft)
      end

      it 'returns upcoming events when starts_at is in the future' do
        upcoming = described_class.create!(name: 'Upcoming', starts_at: 2.days.from_now, identifier: SecureRandom.uuid)
        _past = described_class.create!(name: 'Past', starts_at: 2.days.ago, identifier: SecureRandom.uuid)
        expect(described_class.upcoming).to include(upcoming)
      end

      it 'returns past events when starts_at is in the past' do
        past = described_class.create!(name: 'Past', starts_at: 1.day.ago, identifier: SecureRandom.uuid)
        expect(described_class.past).to include(past)
      end
    end

    describe 'registration_url' do
      it 'allows valid http/https URLs' do
        event.registration_url = 'https://example.org/register'
        expect(event).to be_valid
      end

      it 'rejects invalid URLs' do
        event.registration_url = 'not-a-url'

        expect(event).not_to be_valid
      end

      it 'includes validation error for invalid URL' do
        event.registration_url = 'not-a-url'
        event.valid?

        expect(event.errors[:registration_url]).to be_present
      end
    end
  end
end
