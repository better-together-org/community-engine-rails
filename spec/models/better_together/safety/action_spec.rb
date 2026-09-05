# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Safety::Action do
  subject(:action) do
    described_class.new(
      safety_case: safety_case,
      actor: actor,
      action_type: 'watch_flag',
      status: 'active',
      reason: 'Monitoring for repeat violations',
      review_at: 7.days.from_now
    )
  end

  let(:safety_case) { create(:safety_case) }
  let(:actor) { create(:better_together_person) }

  describe 'validations' do
    it 'is valid with required attributes' do
      expect(action).to be_valid
    end

    it 'requires action_type' do
      action.action_type = nil
      expect(action).not_to be_valid
    end

    it 'requires status' do
      action.status = nil
      expect(action).not_to be_valid
    end

    it 'requires reason' do
      action.reason = nil
      expect(action).not_to be_valid
    end

    it 'requires review_at when status is active' do
      action.review_at = nil
      expect(action).not_to be_valid
      expect(action.errors[:review_at]).to be_present
    end

    it 'does not require review_at when status is completed' do
      action.status = 'completed'
      action.review_at = nil
      expect(action).to be_valid
    end
  end

  describe 'enums' do
    it 'recognizes action_type values' do
      expect(described_class.action_types.keys).to include(
        'content_hidden', 'content_removed', 'contact_restriction',
        'temporary_suspension', 'watch_flag'
      )
    end

    it 'recognizes status values' do
      expect(described_class.statuses.keys).to include('active', 'completed', 'cancelled')
    end
  end

  describe '.active scope' do
    it 'returns only active actions' do
      active = create(:better_together_safety_action, status: 'active')
      completed = create(:better_together_safety_action, status: 'completed', review_at: nil)
      expect(described_class.active).to include(active)
      expect(described_class.active).not_to include(completed)
    end
  end
end
