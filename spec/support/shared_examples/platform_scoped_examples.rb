# frozen_string_literal: true

# Shared examples for all models that include BetterTogether::PlatformScoped.
#
# Usage:
#   it_behaves_like 'platform scoped', factory: :agreement
#   it_behaves_like 'platform scoped identifier', factory: :agreement
#
# The 'platform scoped identifier' examples extend 'platform scoped' and cover
# the additional per-platform uniqueness guarantee provided by the Identifier
# concern's platform-aware validate_identifier_uniqueness method.

RSpec.shared_examples 'platform scoped' do |factory:|
  let(:platform_a) { create(:better_together_platform, host: false) }
  let(:platform_b) { create(:better_together_platform, host: false) }

  describe 'PlatformScoped concern' do
    it 'belongs to a platform' do
      record = build(factory)
      expect(record).to respond_to(:platform)
      expect(record).to respond_to(:platform_id)
    end

    it 'auto-assigns Current.platform on validation when platform_id is blank' do
      BetterTogether::Current.platform = platform_a
      record = build(factory, platform: nil)
      record.valid?
      expect(record.platform).to eq(platform_a)
    ensure
      BetterTogether::Current.platform = nil
    end

    it 'falls back to the host platform when Current.platform is nil' do
      host_platform = BetterTogether::Platform.find_by(host: true) ||
                      create(:better_together_platform, host: true)
      BetterTogether::Current.platform = nil
      record = build(factory, platform: nil)
      record.valid?
      expect(record.platform_id).to eq(host_platform.id)
    end

    it 'does not override an explicitly assigned platform' do
      BetterTogether::Current.platform = platform_a
      record = build(factory, platform: platform_b)
      record.valid?
      expect(record.platform).to eq(platform_b)
    ensure
      BetterTogether::Current.platform = nil
    end

    describe '.for_platform scope' do
      it 'returns records belonging to the given platform' do
        r1 = create(factory, platform: platform_a)
        r2 = create(factory, platform: platform_b)

        result = described_class.for_platform(platform_a)
        expect(result).to include(r1)
        expect(result).not_to include(r2)
      end
    end
  end
end

RSpec.shared_examples 'platform scoped identifier' do |factory:|
  it_behaves_like 'platform scoped', factory: factory

  let(:platform_a) { create(:better_together_platform, host: false) }
  let(:platform_b) { create(:better_together_platform, host: false) }

  describe 'identifier uniqueness (platform-scoped)' do
    let(:shared_identifier) { "shared-id-#{SecureRandom.hex(6)}" }

    it 'allows the same identifier on different platforms' do
      create(factory, identifier: shared_identifier, platform: platform_a)
      record_b = build(factory, identifier: shared_identifier, platform: platform_b)
      expect(record_b).to be_valid
    end

    it 'rejects the same identifier on the same platform' do
      create(factory, identifier: shared_identifier, platform: platform_a)
      duplicate = build(factory, identifier: shared_identifier, platform: platform_a)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:identifier]).to include('has already been taken')
    end

    it 'allows an updated record to keep its own identifier' do
      record = create(factory, identifier: shared_identifier, platform: platform_a)
      record.touch # simulate update without changing identifier
      expect(record).to be_valid
    end
  end
end
