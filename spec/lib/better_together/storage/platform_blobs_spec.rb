# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Storage::PlatformBlobs do
  subject(:blobs) { described_class.new(config) }

  let(:config) { create(:better_together_storage_configuration) }
  let(:platform) { config.platform.tap { |p| p.update!(storage_configuration_id: config.id) } }
  let(:dir) { Dir.mktmpdir('platform-export') }

  def upload(text, platform: nil)
    Current.platform = platform
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new(text), filename: 'a.txt', content_type: 'text/plain')
  ensure
    Current.reset
  end

  after { FileUtils.remove_entry(dir) }

  it 'exports only the platform blobs with a verifiable manifest', :aggregate_failures do
    upload('mine', platform:)
    upload('shared default')

    result = blobs.export(dir)
    manifest = JSON.parse(File.read(File.join(dir, 'MANIFEST.json')))

    expect(result.blob_count).to eq(1)
    expect(manifest['files'].first['sha256']).to eq(Digest::SHA256.hexdigest('mine'))
    expect(File.read(File.join(dir, manifest['files'].first['path']))).to eq('mine')
  end

  it 'lists a blob whose object is missing as skipped' do
    blob = upload('gone', platform:)
    blob.service.delete(blob.key)

    expect(blobs.export(dir).skipped.first['reason']).to eq('missing_object')
  end

  it 'purges nothing on a dry run', :aggregate_failures do
    upload('keep', platform:)

    result = blobs.purge!

    expect(result.blob_count).to eq(1)
    expect(ActiveStorage::Blob.where(service_name: config.storage_key).count).to eq(1)
  end

  it 'purges only the platform blobs when applied', :aggregate_failures do
    upload('drop', platform:)
    other = upload('stay')

    blobs.purge!(apply: true)

    expect(ActiveStorage::Blob.where(service_name: config.storage_key)).to be_empty
    expect(ActiveStorage::Blob.exists?(other.id)).to be(true)
  end
end
