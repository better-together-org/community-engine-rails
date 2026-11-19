# frozen_string_literal: true

# A billing record belongs to exactly one platform and nothing guesses which.
# The including example group provides:
#   build_record(platform:)  - a new, valid record for that platform (platform: may be nil)
RSpec.shared_examples 'a platform-bound billing record' do
  let(:platform_a) { create(:better_together_platform) }
  let(:platform_b) { create(:better_together_platform) }

  after { Current.platform = nil }

  it 'is invalid without a platform when no request platform is current' do
    Current.platform = nil
    record = build_record(platform: nil)

    expect(record).not_to be_valid
    expect(record.errors.details[:platform]).to include(a_hash_including(error: :blank))
  end

  it 'never falls back to the host platform in a job, webhook or console context' do
    configure_host_platform
    Current.platform = nil
    record = build_record(platform: nil)

    record.valid?

    expect(record.platform).to be_nil
  end

  it 'takes the platform from the current request platform' do
    Current.platform = platform_a
    record = build_record(platform: nil)

    expect(record).to be_valid
    expect(record.platform).to eq(platform_a)
  end

  it 'keeps an explicitly given platform over the current request platform' do
    Current.platform = platform_a
    record = build_record(platform: platform_b)

    record.valid?

    expect(record.platform).to eq(platform_b)
  end

  it 'cannot be moved to another platform once saved' do
    record = build_record(platform: platform_a)
    record.save!

    record.platform = platform_b

    expect { record.save! }.to(raise_error do |error|
      expect(error).to be_a(ActiveRecord::RecordInvalid).or be_a(ActiveRecord::ReadonlyAttributeError)
    end)
    expect(record.reload.platform).to eq(platform_a)
  end

  it 'is isolated by for_platform' do
    in_a = build_record(platform: platform_a).tap(&:save!)
    in_b = build_record(platform: platform_b).tap(&:save!)

    expect(described_class.for_platform(platform_a)).to include(in_a)
    expect(described_class.for_platform(platform_a)).not_to include(in_b)
  end

  it 'has a NOT NULL platform column, so the database refuses a platformless row too' do
    expect(described_class.columns_hash.fetch('platform_id').null).to be(false)
  end
end
