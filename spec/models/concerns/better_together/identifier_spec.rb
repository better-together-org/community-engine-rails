# frozen_string_literal: true

require 'rails_helper'

# Tests for BetterTogether::Identifier concern with focus on platform-scoped
# uniqueness — the key behaviour change introduced in the multi-platform
# isolation work. Uses BetterTogether::Agreement as a representative
# platform-scoped model and BetterTogether::Community as a non-platform-scoped
# model to verify the conditional branching.
RSpec.describe BetterTogether::Identifier do
  let(:platform_a) { create(:better_together_platform, host: false) }
  let(:platform_b) { create(:better_together_platform, host: false) }

  # ── Platform-scoped model (Agreement includes both Identifier + PlatformScoped) ──

  describe 'identifier uniqueness for platform-scoped models' do
    let(:shared_id) { "shared-#{SecureRandom.hex(6)}" }

    it 'allows the same identifier on two different platforms' do
      create(:agreement, identifier: shared_id, platform: platform_a)
      cross = build(:agreement, identifier: shared_id, platform: platform_b)
      expect(cross).to be_valid
    end

    it 'rejects the same identifier on the same platform' do
      create(:agreement, identifier: shared_id, platform: platform_a)
      dup = build(:agreement, identifier: shared_id, platform: platform_a)
      expect(dup).not_to be_valid
      expect(dup.errors[:identifier]).to include('has already been taken')
    end

    it 'does not raise uniqueness error when a record is updated in-place' do
      record = create(:agreement, identifier: shared_id, platform: platform_a)
      record.title = "Updated title #{SecureRandom.hex(4)}"
      expect(record).to be_valid
    end
  end

  describe 'auto-generated identifier for platform-scoped models' do
    it 'generates identifiers scoped to the same platform without collision' do
      # Create 3 agreements on platform_a; their auto-generated identifiers
      # must all be unique within that platform.
      agreements = 3.times.map { create(:agreement, platform: platform_a) }
      identifiers = agreements.map(&:identifier)
      expect(identifiers.uniq.length).to eq(3)
    end

    it 'can reuse an identifier on a different platform' do
      # Take an identifier that exists on platform_a and confirm it is
      # accepted when auto-generated on platform_b by building with the same
      # explicit value.
      existing = create(:agreement, platform: platform_a)
      reused = build(:agreement, identifier: existing.identifier, platform: platform_b)
      expect(reused).to be_valid
    end
  end

  # ── Non-platform-scoped model (Community includes only Identifier) ──

  describe 'identifier uniqueness for non-platform-scoped models' do
    it 'enforces global uniqueness when no platform_id column exists' do
      community = create(:community)
      dup = build(:community, identifier: community.identifier)
      expect(dup).not_to be_valid
      expect(dup.errors[:identifier]).to include('has already been taken')
    end
  end
end
