# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Storage::TenantService do
  let(:config) { create(:better_together_storage_configuration) }
  let(:platform) { config.platform.tap { |p| p.update!(storage_configuration_id: config.id) } }
  let(:other_config) { create(:better_together_storage_configuration, name: 'Other') }
  let(:other_platform) { other_config.platform.tap { |p| p.update!(storage_configuration_id: other_config.id) } }

  def upload(text = 'storage router')
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new(text), filename: 'a.txt', content_type: 'text/plain')
  end

  describe '.service_name_for' do
    it 'is nil without a platform or an active configuration', :aggregate_failures do
      expect(described_class.service_name_for(nil)).to be_nil
      expect(described_class.service_name_for(create(:better_together_platform))).to be_nil
    end

    it "is the configuration's storage key" do
      expect(described_class.service_name_for(platform)).to eq(config.storage_key)
    end
  end

  describe 'blob stamping' do
    around do |example|
      Current.set(platform: nil) { example.run }
    end

    it 'leaves the process default when the platform has no configuration' do
      Current.platform = create(:better_together_platform)

      expect(upload.service_name).to eq(ActiveStorage::Blob.service.name.to_s)
    end

    it "stamps new blobs with the current platform's service", :aggregate_failures do
      Current.platform = platform
      blob = upload

      expect(blob.service.name.to_s).to eq(config.storage_key)
      expect(blob.service.name.to_s).to eq(config.storage_key)
      expect(blob.download).to eq('storage router')
    end

    it 'keeps two platforms on their own services', :aggregate_failures do
      Current.platform = platform
      first = upload
      Current.platform = other_platform
      second = upload

      expect([first.service_name, second.service_name].uniq.size).to eq(2)
      expect(first.reload.service_name).to eq(config.storage_key)
    end

    it 'does not move a blob when the platform changes its active configuration' do
      Current.platform = platform
      blob = upload
      platform.update!(storage_configuration_id: other_config.id)

      expect(blob.reload.service_name).to eq(config.storage_key)
    end

    it 'lets an explicit service_name win' do
      Current.platform = platform
      blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new('x'), filename: 'a.txt', service_name: :local)

      expect(blob.service_name).to eq('local')
    end

    it 'stamps direct upload blobs too' do
      Current.platform = platform
      blob = ActiveStorage::Blob.create_before_direct_upload!(
        filename: 'a.txt', byte_size: 1, checksum: Digest::MD5.base64digest('x'), content_type: 'text/plain'
      )

      expect(blob.service.name.to_s).to eq(config.storage_key)
    end
  end
end
