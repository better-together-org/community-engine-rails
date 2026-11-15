# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ConsentPreference do
  let(:person) { create(:better_together_person) }
  let(:preference) { described_class.new(person) }

  it 'has no decision until one is recorded', :aggregate_failures do
    expect(preference.stored?).to be(false)
    expect(preference.decision).to be_nil
    expect(preference.decided_at).to be_nil
    expect(preference.current?('v1')).to be(false)
  end

  describe '#record!' do
    it 'stores both booleans, the date and the policy version in the person preferences', :aggregate_failures do
      at = Time.zone.parse('2026-11-14 10:00:00 UTC')
      preference.record!({ 'analytics' => true }, policy_version: 'v1', at:)

      reloaded = described_class.new(person.reload)
      expect(reloaded.decision).to eq('analytics' => true, 'marketing' => false)
      expect(reloaded.decided_at).to eq(at)
      expect(reloaded.policy_version).to eq('v1')
      expect(person.reload.preferences['cookie_consent']).to include('analytics' => true, 'policy_version' => 'v1')
    end

    it 'counts only literal true as consent' do
      preference.record!({ 'analytics' => 'yes', 'marketing' => 1 }, policy_version: 'v1')

      expect(preference.decision).to eq('analytics' => false, 'marketing' => false)
    end

    it 'keeps the other preferences' do
      person.update!(time_zone: 'America/Halifax')
      preference.record!({}, policy_version: 'v1')

      expect(person.reload.time_zone).to eq('America/Halifax')
    end
  end

  describe '#current?' do
    it 'is true only for the version the decision was made under', :aggregate_failures do
      preference.record!({}, policy_version: 'v1')

      expect(preference.current?('v1')).to be(true)
      expect(preference.current?('v2')).to be(false)
    end
  end

  describe '#withdraw!' do
    it 'records a decision that declines every category' do
      preference.record!({ 'analytics' => true, 'marketing' => true }, policy_version: 'v1')
      preference.withdraw!(policy_version: 'v1')

      expect(preference.decision).to eq('analytics' => false, 'marketing' => false)
    end
  end
end
