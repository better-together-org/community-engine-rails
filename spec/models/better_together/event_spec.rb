# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe Event, type: :model do
    subject(:event) { described_class.new(name: 'Event', starts_at: Time.current) }

    it 'exists' do
      expect(described_class).to be
    end

    it 'requires starts_at' do
      event.starts_at = nil
      expect(event).not_to be_valid
      expect(event.errors[:starts_at]).to include("can't be blank")
    end

    it 'requires ends_at to be after starts_at' do
      event.ends_at = event.starts_at - 1.hour
      expect(event).not_to be_valid
      expect(event.errors[:ends_at]).to include(I18n.t('errors.models.ends_at_before_starts_at'))
    end

    it 'is valid when ends_at is after starts_at' do
      event.ends_at = event.starts_at + 1.hour
      expect(event).to be_valid
    end
  end
end
