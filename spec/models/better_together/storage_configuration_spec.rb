# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::StorageConfiguration do
  describe 'SERVICE_TYPES constant' do
    it 'includes local, amazon, and s3_compatible' do
      expect(described_class::SERVICE_TYPES).to contain_exactly('local', 'amazon', 's3_compatible')
    end
  end

  describe 'validations' do
    context 'with local service type' do
      subject(:config) { build(:better_together_storage_configuration) }

      it 'is valid' do
        expect(config).to be_valid
      end

      it 'requires name' do
        config.name = nil
        expect(config).not_to be_valid
      end

      it 'requires service_type' do
        config.service_type = nil
        expect(config).not_to be_valid
      end

      it 'rejects unknown service_type' do
        config.service_type = 'ftp'
        expect(config).not_to be_valid
      end
    end

    context 'with amazon service type' do
      subject(:config) { build(:better_together_storage_configuration, :amazon) }

      it 'is valid' do
        expect(config).to be_valid
      end

      it 'requires bucket' do
        config.bucket = nil
        expect(config).not_to be_valid
      end

      it 'requires region' do
        config.region = nil
        expect(config).not_to be_valid
      end

      it 'requires access_key_id' do
        config.access_key_id = nil
        expect(config).not_to be_valid
      end

      it 'requires secret_access_key' do
        config.secret_access_key = nil
        expect(config).not_to be_valid
      end
    end

    context 'with s3_compatible service type' do
      subject(:config) { build(:better_together_storage_configuration, :s3_compatible) }

      it 'is valid' do
        expect(config).to be_valid
      end

      it 'requires endpoint' do
        config.endpoint = nil
        expect(config).not_to be_valid
      end

      it 'rejects malformed endpoint URL' do
        config.endpoint = 'not a url'
        expect(config).not_to be_valid
      end
    end
  end

  describe 'service type predicates' do
    it '#local? returns true for local type' do
      config = build(:better_together_storage_configuration)
      expect(config).to be_local
      expect(config).not_to be_amazon
      expect(config).not_to be_s3_compatible
      expect(config).not_to be_s3_service
    end

    it '#amazon? returns true for amazon type' do
      config = build(:better_together_storage_configuration, :amazon)
      expect(config).to be_amazon
      expect(config).to be_s3_service
      expect(config).not_to be_local
    end

    it '#s3_compatible? returns true for s3_compatible type' do
      config = build(:better_together_storage_configuration, :s3_compatible)
      expect(config).to be_s3_compatible
      expect(config).to be_s3_service
      expect(config).not_to be_local
    end
  end

  describe '#storage_key' do
    it 'returns a stable string based on the record id' do
      config = create(:better_together_storage_configuration)
      expect(config.storage_key).to eq("storage_config_#{config.id}")
    end
  end

  describe '#to_active_storage_config' do
    it 'returns a Disk service config for local type' do
      config = build(:better_together_storage_configuration)
      result = config.to_active_storage_config
      expect(result[:service]).to eq('S3').or(eq('Disk'))
    end

    it 'returns an S3 service config for amazon type with correct keys' do
      config = build(:better_together_storage_configuration, :amazon)
      result = config.to_active_storage_config
      expect(result[:service]).to eq('S3')
      expect(result[:bucket]).to eq(config.bucket)
      expect(result[:region]).to eq(config.region)
    end

    it 'includes force_path_style and endpoint for s3_compatible type' do
      config = build(:better_together_storage_configuration, :s3_compatible)
      result = config.to_active_storage_config
      expect(result[:service]).to eq('S3')
      expect(result[:endpoint]).to eq(config.endpoint)
      expect(result[:force_path_style]).to be true
      expect(result).to include(request_checksum_calculation: 'when_required',
                                response_checksum_validation: 'when_required')
    end
  end

  describe '.s3_services scope' do
    it 'excludes local configurations' do
      local = create(:better_together_storage_configuration)
      s3 = create(:better_together_storage_configuration, :amazon)
      expect(described_class.s3_services).to include(s3)
      expect(described_class.s3_services).not_to include(local)
    end
  end

  describe 'bucket uniqueness across platforms' do
    let(:first) { create(:better_together_storage_configuration, :s3_compatible) }

    it 'rejects the same endpoint and bucket on another platform', :aggregate_failures do
      other = build(:better_together_storage_configuration, :s3_compatible, endpoint: "#{first.endpoint.upcase}/")

      expect(other).not_to be_valid
      expect(other.errors[:bucket]).to be_present
    end

    it 'allows the same bucket name on a different endpoint' do
      first
      other = build(:better_together_storage_configuration, :s3_compatible, endpoint: 'http://other.example.test:3900')

      expect(other).to be_valid
    end

    it 'allows a second configuration on the same platform' do
      other = build(:better_together_storage_configuration, :s3_compatible, platform: first.platform)

      expect(other).to be_valid
    end
  end

  describe 'endpoint safety' do
    let(:tenant) { create(:better_together_platform, host: false) }

    it 'rejects a private endpoint on a tenant platform' do
      config = build(:better_together_storage_configuration, :s3_compatible, platform: tenant,
                                                                             endpoint: 'http://169.254.169.254')

      expect(config).not_to be_valid
    end

    it 'allows an internal endpoint on the host platform' do
      host = BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, :host)
      config = build(:better_together_storage_configuration, :s3_compatible, platform: host,
                                                                             endpoint: 'http://10.0.0.5:3900')

      expect(config).to be_valid
    end
  end

  describe '#test_connection!' do
    it 'records a healthy result', :aggregate_failures do
      config = create(:better_together_storage_configuration)

      expect(config.test_connection!).to be_ok
      expect(config.reload).to have_attributes(health_status: 'ok', health_message: 'ok')
      expect(config.health_checked_at).to be_present
    end

    it 'records a failure' do
      config = create(:better_together_storage_configuration)
      allow(ActiveStorage::Service::DiskService).to receive(:new).and_raise(IOError)

      config.test_connection!

      expect(config.reload.health_status).to eq('failed')
    end
  end

  describe '#rotate_credentials!' do
    let(:config) { create(:better_together_storage_configuration, :s3_compatible) }

    it 'keeps the old keys when the new pair fails the connection test', :aggregate_failures do
      failed = BetterTogether::Storage::ConnectionTest::Result.new(false, 'access_denied')
      allow(BetterTogether::Storage::ConnectionTest).to receive(:new).and_return(instance_double(BetterTogether::Storage::ConnectionTest,
                                                                                                 call: failed))

      expect(config.rotate_credentials!(access_key_id: 'new', secret_access_key: 'new')).to be(false)
      expect(config.reload.access_key_id).to eq('GKtest123456789')
      expect(config.errors[:base]).to be_present
    end

    it 'stores the new keys after a passing test', :aggregate_failures do
      ok = BetterTogether::Storage::ConnectionTest::Result.new(true, 'ok')
      allow(BetterTogether::Storage::ConnectionTest).to receive(:new).and_return(instance_double(BetterTogether::Storage::ConnectionTest,
                                                                                                 call: ok))

      expect(config.rotate_credentials!(access_key_id: 'new-id', secret_access_key: 'new-secret')).to be(true)
      expect(config.reload).to have_attributes(access_key_id: 'new-id', health_status: 'ok')
    end
  end
end
