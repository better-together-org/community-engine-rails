# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::StorageResolver do # rubocop:todo RSpec/MultipleMemoizedHelpers
  subject(:resolver) { described_class.new(platform) }

  let(:platform) { nil }

  describe '#env_based?' do
    context 'when no platform is given' do
      it { expect(resolver.env_based?).to be(true) }
    end

    context 'when platform has no active_storage_configuration' do
      let(:platform) { create(:better_together_platform) }

      it { expect(resolver.env_based?).to be(true) }
    end

    context 'when platform has an active_storage_configuration' do
      let(:config) { create(:better_together_storage_configuration) }
      let(:platform) { config.platform.tap { |p| p.update!(storage_configuration_id: config.id) } }

      it { expect(resolver.env_based?).to be(false) }
    end
  end

  describe '#service_name' do
    context 'when env-based with ACTIVE_STORAGE_SERVICE=local' do
      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('ACTIVE_STORAGE_SERVICE', 'local').and_return('local')
      end

      it { expect(resolver.service_name).to eq(:local) }
    end

    context 'when env-based with ACTIVE_STORAGE_SERVICE=amazon' do
      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('ACTIVE_STORAGE_SERVICE', 'local').and_return('amazon')
      end

      it { expect(resolver.service_name).to eq(:amazon) }
    end

    context 'when env-based with an unknown ACTIVE_STORAGE_SERVICE value' do
      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('ACTIVE_STORAGE_SERVICE', 'local').and_return('bogus_backend')
      end

      it 'falls back to :local and logs a warning' do
        allow(Rails.logger).to receive(:warn)
        expect(resolver.service_name).to eq(:local)
      end
    end

    context 'when platform config is active' do
      let(:config) { create(:better_together_storage_configuration, :amazon) }
      let(:platform) { config.platform.tap { |p| p.update!(storage_configuration_id: config.id) } }

      it 'returns the config storage key' do
        expect(resolver.service_name).to eq(config.storage_key.to_sym)
      end
    end
  end

  describe '#summary' do
    context 'when env-based (no platform config)' do
      it 'returns a hash with source: :env' do
        expect(resolver.summary[:source]).to eq(:env)
      end

      it 'includes service_type, bucket, endpoint, region, asset_host, cdn_host keys' do
        expect(resolver.summary.keys).to include(:service_type, :bucket, :endpoint, :region, :asset_host, :cdn_host)
      end

      context 'with ASSET_HOST and FOG_HOST set' do
        before do
          allow(ENV).to receive(:fetch).and_call_original
          allow(ENV).to receive(:fetch).with('ASSET_HOST', nil).and_return('https://assets.example.com')
          allow(ENV).to receive(:fetch).with('FOG_HOST', nil).and_return('https://cdn.example.com')
        end

        it 'surfaces ASSET_HOST in summary' do
          expect(resolver.summary[:asset_host]).to eq('https://assets.example.com')
        end

        it 'surfaces FOG_HOST as cdn_host in summary' do
          expect(resolver.summary[:cdn_host]).to eq('https://cdn.example.com')
        end
      end

      context 'without ASSET_HOST or FOG_HOST' do
        before do
          allow(ENV).to receive(:fetch).and_call_original
          allow(ENV).to receive(:fetch).with('ASSET_HOST', nil).and_return(nil)
          allow(ENV).to receive(:fetch).with('FOG_HOST', nil).and_return(nil)
        end

        it 'has nil asset_host' do
          expect(resolver.summary[:asset_host]).to be_nil
        end

        it 'has nil cdn_host' do
          expect(resolver.summary[:cdn_host]).to be_nil
        end
      end

      context 'with S3 env vars set' do
        before do
          allow(ENV).to receive(:fetch).and_call_original
          allow(ENV).to receive(:fetch).with('ACTIVE_STORAGE_SERVICE', 'local').and_return('amazon')
          allow(ENV).to receive(:fetch).with('S3_BUCKET_NAME', anything).and_return('my-bucket')
          allow(ENV).to receive(:fetch).with('S3_ENDPOINT', nil).and_return('https://s3.example.com')
          allow(ENV).to receive(:fetch).with('S3_REGION', anything).and_return('ca-central-1')
        end

        it 'surfaces the bucket' do
          expect(resolver.summary[:bucket]).to eq('my-bucket')
        end

        it 'surfaces the endpoint' do
          expect(resolver.summary[:endpoint]).to eq('https://s3.example.com')
        end

        it 'surfaces the region' do
          expect(resolver.summary[:region]).to eq('ca-central-1')
        end
      end

      context 'with FOG_DIRECTORY fallback (no S3_BUCKET_NAME)' do
        before do
          allow(ENV).to receive(:fetch).and_call_original
          allow(ENV).to receive(:fetch).with('ACTIVE_STORAGE_SERVICE', 'local').and_return('amazon')
          allow(ENV).to receive(:fetch).with('S3_BUCKET_NAME', anything) do |_key, fallback|
            fallback.is_a?(String) ? fallback : nil
          end
          allow(ENV).to receive(:fetch).with('FOG_DIRECTORY', nil).and_return('fog-bucket')
        end

        it 'falls back to FOG_DIRECTORY for bucket' do
          expect(resolver.summary[:bucket]).to eq('fog-bucket')
        end
      end
    end

    context 'when platform config is active' do
      let(:config) { create(:better_together_storage_configuration, :amazon) }
      let(:platform) { config.platform.tap { |p| p.update!(storage_configuration_id: config.id) } }

      it 'returns a hash with source: :platform_config' do
        expect(resolver.summary[:source]).to eq(:platform_config)
      end

      it 'includes config details' do
        s = resolver.summary
        expect(s[:config_id]).to eq(config.id)
        expect(s[:service_type]).to eq('amazon')
        expect(s[:bucket]).to eq(config.bucket)
      end

      it 'still includes asset_host and cdn_host keys from env' do
        expect(resolver.summary.keys).to include(:asset_host, :cdn_host)
      end

      context 'with ASSET_HOST set' do
        before do
          allow(ENV).to receive(:fetch).and_call_original
          allow(ENV).to receive(:fetch).with('ASSET_HOST', nil).and_return('https://assets.example.com')
        end

        it 'surfaces ASSET_HOST even for platform config source' do
          expect(resolver.summary[:asset_host]).to eq('https://assets.example.com')
        end
      end
    end
  end

  describe '#to_active_storage_config' do
    context 'when env-based local' do
      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('ACTIVE_STORAGE_SERVICE', 'local').and_return('local')
      end

      it 'returns a Disk service hash' do
        expect(resolver.to_active_storage_config[:service]).to eq('Disk')
      end

      it 'includes a root path' do
        expect(resolver.to_active_storage_config[:root]).to be_present
      end
    end

    context 'when env-based S3 with endpoint' do
      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('ACTIVE_STORAGE_SERVICE', 'local').and_return('amazon')
        allow(ENV).to receive(:fetch).with('AWS_ACCESS_KEY_ID', nil).and_return('AKIAIOSFODNN7EXAMPLE')
        allow(ENV).to receive(:fetch).with('AWS_SECRET_ACCESS_KEY', nil).and_return('secret')
        allow(ENV).to receive(:fetch).with('S3_BUCKET_NAME', anything).and_return('test-bucket')
        allow(ENV).to receive(:fetch).with('S3_ENDPOINT', nil).and_return('https://s3.custom.example.com')
        allow(ENV).to receive(:fetch).with('S3_REGION', anything).and_return('us-east-1')
      end

      it 'returns an S3 service hash' do
        expect(resolver.to_active_storage_config[:service]).to eq('S3')
      end

      it 'enables force_path_style when endpoint is set' do
        expect(resolver.to_active_storage_config[:force_path_style]).to be(true)
      end

      it 'includes the bucket' do
        expect(resolver.to_active_storage_config[:bucket]).to eq('test-bucket')
      end
    end

    context 'when env-based S3 without endpoint (Amazon)' do
      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('ACTIVE_STORAGE_SERVICE', 'local').and_return('amazon')
        allow(ENV).to receive(:fetch).with('S3_ENDPOINT', nil).and_return(nil)
        allow(ENV).to receive(:fetch).with('S3_BUCKET_NAME', anything).and_return('amazon-bucket')
      end

      it 'does not set force_path_style' do
        expect(resolver.to_active_storage_config).not_to have_key(:force_path_style)
      end
    end

    context 'when platform config is active' do
      let(:config) { create(:better_together_storage_configuration, :s3_compatible) }
      let(:platform) { config.platform.tap { |p| p.update!(storage_configuration_id: config.id) } }

      it 'delegates to the config model' do
        expect(resolver.to_active_storage_config).to eq(config.to_active_storage_config)
      end
    end
  end
end
