# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Storage::Usage do
  let(:config) { create(:better_together_storage_configuration) }
  let(:platform) { config.platform.tap { |p| p.update!(storage_configuration_id: config.id) } }

  def upload(text, platform: nil)
    Current.platform = platform
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new(text), filename: 'a.txt', content_type: 'text/plain')
  ensure
    Current.reset
  end

  it 'counts only blobs stored on the platform service', :aggregate_failures do
    upload('12345', platform:)
    upload('123', platform:)
    upload('ignored bytes elsewhere')

    expect(described_class.bytes_for(config)).to eq(8)
    expect(described_class.blob_count_for(config)).to eq(2)
    expect(config.used_bytes).to eq(8)
  end

  it 'is nil for a platform on the shared default' do
    expect(described_class.bytes_for_platform(create(:better_together_platform))).to be_nil
  end

  it 'checks an allowance', :aggregate_failures do
    upload('12345', platform:)

    expect(described_class.within_allowance?(platform, incoming: 5, allowance_bytes: 10)).to be(true)
    expect(described_class.within_allowance?(platform, incoming: 6, allowance_bytes: 10)).to be(false)
    expect(described_class.within_allowance?(platform, incoming: 99, allowance_bytes: nil)).to be(true)
  end
end
