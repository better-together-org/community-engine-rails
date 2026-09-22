# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/VerifiedDoubles
RSpec.describe BetterTogether::ContentSecurity::Configuration, type: :service do
  let(:malware_scanning_config) do
    double('malware_scanning',
           enabled: true,
           engine: 'clamav',
           fail_mode: 'hold_until_clean',
           host: '127.0.0.1',
           port: 3310,
           timeout: 15.0,
           max_stream_bytes: 10_485_760,
           enabled_surfaces: %w[post_attachments mail_attachments])
  end
  let(:content_security_config) { double('content_security', malware_scanning: malware_scanning_config) }

  before do
    allow(BetterTogether).to receive(:content_security).and_return(content_security_config)
  end

  describe '.enabled?' do
    it 'returns true when malware_scanning.enabled is true' do
      expect(described_class.enabled?).to be true
    end

    it 'returns false when malware_scanning.enabled is false' do
      allow(malware_scanning_config).to receive(:enabled).and_return(false)
      expect(described_class.enabled?).to be false
    end

    it 'returns false when malware_scanning.enabled is nil' do
      allow(malware_scanning_config).to receive(:enabled).and_return(nil)
      expect(described_class.enabled?).to be false
    end
  end

  describe '.engine' do
    it 'returns the engine as a string' do
      expect(described_class.engine).to eq('clamav')
    end
  end

  describe '.fail_mode' do
    it 'returns the configured fail_mode' do
      expect(described_class.fail_mode).to eq('hold_until_clean')
    end

    it 'defaults to hold_until_clean when blank' do
      allow(malware_scanning_config).to receive(:fail_mode).and_return(nil)
      expect(described_class.fail_mode).to eq('hold_until_clean')
    end
  end

  describe '.host' do
    it 'returns the host as a string' do
      expect(described_class.host).to eq('127.0.0.1')
    end
  end

  describe '.port' do
    it 'returns the port as an integer' do
      expect(described_class.port).to eq(3310)
    end
  end

  describe '.timeout' do
    it 'returns the configured timeout' do
      expect(described_class.timeout).to eq(15.0)
    end

    it 'defaults to 10.0 when timeout is zero' do
      allow(malware_scanning_config).to receive(:timeout).and_return(0)
      expect(described_class.timeout).to eq(10.0)
    end

    it 'defaults to 10.0 when timeout is nil' do
      allow(malware_scanning_config).to receive(:timeout).and_return(nil)
      expect(described_class.timeout).to eq(10.0)
    end
  end

  describe '.max_stream_bytes' do
    it 'returns the configured max_stream_bytes when positive' do
      expect(described_class.max_stream_bytes).to eq(10_485_760)
    end

    it 'defaults to 25 megabytes when zero' do
      allow(malware_scanning_config).to receive(:max_stream_bytes).and_return(0)
      expect(described_class.max_stream_bytes).to eq(25.megabytes)
    end

    it 'defaults to 25 megabytes when nil' do
      allow(malware_scanning_config).to receive(:max_stream_bytes).and_return(nil)
      expect(described_class.max_stream_bytes).to eq(25.megabytes)
    end
  end

  describe '.enabled_surfaces' do
    it 'returns the list of enabled surfaces as strings' do
      expect(described_class.enabled_surfaces).to eq(%w[post_attachments mail_attachments])
    end

    it 'returns an empty array when surfaces is nil' do
      allow(malware_scanning_config).to receive(:enabled_surfaces).and_return(nil)
      expect(described_class.enabled_surfaces).to eq([])
    end
  end

  describe '.enabled_for_surface?' do
    it 'returns true for a configured surface' do
      expect(described_class.enabled_for_surface?('post_attachments')).to be true
    end

    it 'accepts symbol surface names' do
      expect(described_class.enabled_for_surface?(:post_attachments)).to be true
    end

    it 'returns false for an unconfigured surface' do
      expect(described_class.enabled_for_surface?('unknown_surface')).to be false
    end
  end
end
# rubocop:enable RSpec/VerifiedDoubles
