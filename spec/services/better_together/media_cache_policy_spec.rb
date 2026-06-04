# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::MediaCachePolicy, type: :service do
  describe '.for_blob' do
    let(:blob) { instance_double(ActiveStorage::Blob) }

    it 'is public when the blob is publicly proxyable' do
      allow(BetterTogether::ContentSecurity::BlobAccessPolicy).to receive(:public_proxy_allowed?).with(blob).and_return(true)

      policy = described_class.for_blob(blob)

      expect(policy.public?).to be(true)
      expect(policy.cache_scope).to eq('public')
    end

    it 'is private when the blob is not publicly proxyable' do
      allow(BetterTogether::ContentSecurity::BlobAccessPolicy).to receive(:public_proxy_allowed?).with(blob).and_return(false)

      policy = described_class.for_blob(blob)

      expect(policy.public?).to be(false)
      expect(policy.cache_scope).to eq('private')
      expect(policy.private_cache_control?).to be(true)
    end
  end

  describe '.for_upload' do
    let(:upload) { instance_double(BetterTogether::Upload, privacy_public?: privacy_public, file_content_security_downloadable?: downloadable) }
    let(:privacy_public) { true }
    let(:downloadable) { true }

    it 'marks public downloadable uploads as public' do
      policy = described_class.for_upload(upload)

      expect(policy.public?).to be(true)
      expect(policy.cache_scope).to eq('public')
    end

    it 'marks non-public uploads as private' do
      allow(upload).to receive(:privacy_public?).and_return(false)

      policy = described_class.for_upload(upload)

      expect(policy.public?).to be(false)
      expect(policy.cache_scope).to eq('private')
    end
  end
end
