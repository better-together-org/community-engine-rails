# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::BreakGlassGrant do
  describe 'state' do
    it 'is active between availability and expiry' do
      grant = build(:better_together_break_glass_grant)
      expect([grant.state, grant.active_now?]).to eq([:active, true])
    end

    it 'is pending before the delay has passed' do
      grant = build(:better_together_break_glass_grant, :pending)
      expect([grant.state, grant.active_now?]).to eq([:pending, false])
    end

    it 'is expired after expiry' do
      grant = build(:better_together_break_glass_grant, :expired)
      expect([grant.state, grant.active_now?]).to eq([:expired, false])
    end

    it 'is revoked once revoked, even inside the window' do
      grant = build(:better_together_break_glass_grant, :revoked)
      expect([grant.state, grant.active_now?]).to eq([:revoked, false])
    end

    it 'lists only currently usable grants in .current' do
      usable = create(:better_together_break_glass_grant)
      create(:better_together_break_glass_grant, :pending)
      create(:better_together_break_glass_grant, :expired)
      create(:better_together_break_glass_grant, :revoked)

      expect(described_class.current).to contain_exactly(usable)
    end
  end

  describe 'validation' do
    it 'requires a substantive reason' do
      expect(build(:better_together_break_glass_grant, reason: 'short')).not_to be_valid
    end

    it 'requires a reason code for an emergency' do
      expect(build(:better_together_break_glass_grant, emergency: true, reason_code: nil)).not_to be_valid
    end

    it 'caps the duration' do
      grant = build(:better_together_break_glass_grant, expires_at: 30.days.from_now)
      expect(grant).not_to be_valid
    end

    it 'only allows listed subject types' do
      grant = build(:better_together_break_glass_grant)
      grant.subject_type = 'BetterTogether::Person'
      expect(grant).not_to be_valid
    end
  end

  it 'can never be destroyed' do
    grant = create(:better_together_break_glass_grant)
    expect(grant.destroy).to be false
    expect(described_class.exists?(grant.id)).to be true
  end
end
