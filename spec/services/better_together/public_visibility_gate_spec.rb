# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PublicVisibilityGate do
  let!(:publishing_agreement) do
    BetterTogether::Agreement.find_or_create_by!(identifier: described_class::AGREEMENT_IDENTIFIER) do |agreement|
      agreement.title = 'Content Publishing Agreement'
      agreement.privacy = 'public'
      agreement.protected = true
    end
  end

  let(:person) { create(:better_together_person) }
  let(:robot) { create(:robot) }
  let(:page) { build(:better_together_page, privacy: 'public') }

  describe '.evaluate' do
    it 'allows private records without the publishing agreement' do
      result = described_class.evaluate(record: build(:better_together_page, privacy: 'private'), actor: person)

      expect(result.allowed?).to be(true)
      expect(result.reasons).to be_empty
    end

    it 'denies public visibility when the actor has not accepted the agreement' do
      result = described_class.evaluate(record: page, actor: person, target_privacy: 'public')

      expect(result.allowed?).to be(false)
      expect(result.reasons).to include(:missing_publishing_agreement)
    end

    it 'allows a person actor after agreement acceptance' do
      create(:better_together_agreement_participant,
             agreement: publishing_agreement,
             participant: person,
             accepted_at: Time.current)

      result = described_class.evaluate(record: page, actor: person, target_privacy: 'public')

      expect(result.allowed?).to be(true)
    end

    it 'allows a robot actor after agreement acceptance' do
      create(:better_together_agreement_participant,
             agreement: publishing_agreement,
             participant: robot,
             accepted_at: Time.current)

      result = described_class.evaluate(record: page, actor: robot, target_privacy: 'public')

      expect(result.allowed?).to be(true)
    end
  end
end
