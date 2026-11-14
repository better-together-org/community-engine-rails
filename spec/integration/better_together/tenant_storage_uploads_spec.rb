# frozen_string_literal: true

require 'rails_helper'

# Direct uploads and variants follow the platform's storage service, not the process default.
RSpec.describe 'Tenant storage uploads and variants' do
  let(:platform) { create(:better_together_platform) }
  let(:config) do
    create(:better_together_storage_configuration, :s3_compatible, platform:,
                                                                   endpoint: 'http://garage.example.test:3900')
  end
  let(:png) do
    "\x89PNG\r\n\x1A\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\b\x06\x00\x00\x00\x1F\x15\xC4\x89\x00" \
      "\x00\x00\nIDATx\x9Cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xB4\x00\x00\x00\x00IEND\xAEB`\x82"
  end

  before do
    platform.update!(storage_configuration_id: config.id)
    Current.platform = platform
  end

  after { Current.reset }

  it 'presigns a direct upload against the platform endpoint', :aggregate_failures do
    blob = ActiveStorage::Blob.create_before_direct_upload!(
      filename: 'a.png', byte_size: 4, checksum: Digest::MD5.base64digest('test'), content_type: 'image/png'
    )

    expect(blob.service_name).to eq(config.storage_key)
    expect(URI(blob.service_url_for_direct_upload).host).to eq('garage.example.test')
  end

  it 'writes a variant to the same service as its original', :aggregate_failures do
    local = create(:better_together_storage_configuration, platform:)
    platform.update!(storage_configuration_id: local.id)
    Current.platform = platform.reload
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(png), filename: 'a.png', content_type: 'image/png')

    variant = blob.variant(resize_to_limit: [1, 1]).processed

    expect(blob.service_name).to eq(local.storage_key)
    expect(blob.service.exist?(variant.key)).to be(true)
    expect(ActiveStorage::Blob.service.exist?(variant.key)).to be(false)
  end
end
