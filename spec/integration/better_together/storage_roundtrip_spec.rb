# frozen_string_literal: true

require 'rails_helper'

# Live check against a real S3-compatible bucket (for example a Garage bucket). It never runs in the
# default suite: set STORAGE_ROUNDTRIP_ENDPOINT, STORAGE_ROUNDTRIP_BUCKET, STORAGE_ROUNDTRIP_KEY_ID and
# STORAGE_ROUNDTRIP_SECRET to run it, and use a throwaway bucket you are allowed to write to.
RSpec.describe 'Storage round trip against a real bucket', :env_required do
  let(:env) do
    ENV.slice('STORAGE_ROUNDTRIP_ENDPOINT', 'STORAGE_ROUNDTRIP_BUCKET', 'STORAGE_ROUNDTRIP_KEY_ID',
              'STORAGE_ROUNDTRIP_SECRET')
  end
  let(:platform) { BetterTogether::Platform.find_by(host: true) }
  let(:config) do
    platform.storage_configurations.create!(
      name: 'roundtrip', service_type: 's3_compatible', endpoint: env['STORAGE_ROUNDTRIP_ENDPOINT'],
      bucket: env['STORAGE_ROUNDTRIP_BUCKET'], region: 'garage',
      access_key_id: env['STORAGE_ROUNDTRIP_KEY_ID'], secret_access_key: env['STORAGE_ROUNDTRIP_SECRET']
    )
  end

  before { skip 'set the STORAGE_ROUNDTRIP_* variables to run' if env.size < 4 }

  # A skipped example still runs after hooks, and `config` would try to create an invalid row.
  after do
    next if env.size < 4

    Current.reset
    platform.update!(storage_configuration_id: nil)
    config.destroy
  end

  it 'stamps, uploads, reads, presigns and purges through a platform configuration', :aggregate_failures do
    expect(config.test_connection!).to be_ok
    platform.update!(storage_configuration_id: config.id)
    Current.platform = platform
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new('roundtrip'), filename: 'r.txt',
                                                  content_type: 'text/plain')

    expect(blob.service_name).to eq(config.storage_key)
    expect(blob.download).to eq('roundtrip')
    expect(URI(blob.url).host).to eq(URI(env['STORAGE_ROUNDTRIP_ENDPOINT']).host)
    blob.purge
    expect(blob.service.exist?(blob.key)).to be(false)
  end
end
