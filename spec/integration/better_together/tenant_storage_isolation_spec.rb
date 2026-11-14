# frozen_string_literal: true

require 'rails_helper'

# Two platforms, two storage configurations: blobs, variants and reads stay on their own service.
RSpec.describe 'Tenant storage isolation' do
  let(:config_a) { create(:better_together_storage_configuration, name: 'A') }
  let(:config_b) { create(:better_together_storage_configuration, name: 'B') }
  let(:platform_a) { config_a.platform.tap { |p| p.update!(storage_configuration_id: config_a.id) } }
  let(:platform_b) { config_b.platform.tap { |p| p.update!(storage_configuration_id: config_b.id) } }
  let(:png) do
    "\x89PNG\r\n\x1A\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\b\x06\x00\x00\x00\x1F\x15\xC4\x89\x00" \
      "\x00\x00\nIDATx\x9Cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xB4\x00\x00\x00\x00IEND\xAEB`\x82"
  end

  # Local configurations all share one disk root, so give each a root of its own, standing in for a bucket.
  before do
    roots = { config_a => Dir.mktmpdir('tenant-a'), config_b => Dir.mktmpdir('tenant-b') }
    roots.each do |config, root|
      allow_any_instance_of(BetterTogether::StorageConfiguration) # rubocop:disable RSpec/AnyInstance
        .to receive(:to_active_storage_config).and_wrap_original do |original, *args|
          original.receiver.id == config.id ? { service: 'Disk', root: } : original.call(*args)
        end
    end
  end

  def upload_as(platform, bytes = png)
    Current.platform = platform
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new(bytes), filename: 'a.png', content_type: 'image/png')
  ensure
    Current.reset
  end

  it 'stamps each platform with its own service', :aggregate_failures do
    a = upload_as(platform_a)
    b = upload_as(platform_b)

    expect(a.service_name).to eq(config_a.storage_key)
    expect(b.service_name).to eq(config_b.storage_key)
  end

  it "does not find one platform's object through the other's service", :aggregate_failures do
    a = upload_as(platform_a)
    registry = ActiveStorage::Blob.services

    expect(registry.fetch(config_a.storage_key).exist?(a.key)).to be(true)
    expect(registry.fetch(config_b.storage_key).exist?(a.key)).to be(false)
  end

  it 'keeps variants on the original blob service', :aggregate_failures do
    variant = upload_as(platform_a).variant(resize_to_limit: [1, 1]).processed

    expect(ActiveStorage::Blob.services.fetch(config_a.storage_key).exist?(variant.key)).to be(true)
    expect(ActiveStorage::Blob.services.fetch(config_b.storage_key).exist?(variant.key)).to be(false)
  end

  it "purging one platform's blob leaves the other's untouched" do
    a = upload_as(platform_a)
    b = upload_as(platform_b)

    a.purge

    expect(b.reload.service.exist?(b.key)).to be(true)
  end

  it 'refuses a second platform that points at the same bucket' do
    first = create(:better_together_storage_configuration, :s3_compatible)
    clash = build(:better_together_storage_configuration, :s3_compatible, endpoint: first.endpoint)

    expect(clash).not_to be_valid
  end
end
