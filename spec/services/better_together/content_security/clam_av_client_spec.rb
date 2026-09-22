# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ContentSecurity::ClamAvClient, type: :service do
  let(:host) { ENV.fetch('CLAMAV_HOST', '127.0.0.1') }
  let(:port) { ENV.fetch('CLAMAV_PORT', '3310').to_i }
  let(:client) { described_class.new(host:, port:, timeout: 5.0, max_stream_bytes: 25.megabytes) }

  describe '#parse_response (via private send)' do
    it 'returns clean status for an OK response' do
      result = client.send(:parse_response, 'stream: OK')
      expect(result[:status]).to eq(:clean)
      expect(result[:signature_name]).to be_nil
    end

    it 'returns infected status when FOUND is in the response' do
      result = client.send(:parse_response, 'stream: Eicar-Signature FOUND')
      expect(result[:status]).to eq(:infected)
      expect(result[:signature_name]).to include('Eicar-Signature')
    end

    it 'raises ClamAvClient::Error for unrecognized responses' do
      expect { client.send(:parse_response, 'stream: UNKNOWN ERROR') }
        .to raise_error(BetterTogether::ContentSecurity::ClamAvClient::Error)
    end
  end

  describe '#scan_file' do
    it 'raises Error when file exceeds the stream limit' do
      large_file = Tempfile.new('big')
      large_file.write('x' * 1025)
      large_file.flush

      small_client = described_class.new(host:, port:, timeout: 5.0, max_stream_bytes: 1024)

      expect { small_client.scan_file(large_file.path) }
        .to raise_error(BetterTogether::ContentSecurity::ClamAvClient::Error, /exceeds.*stream limit/)
    ensure
      large_file.close
      large_file.unlink
    end

    context 'when ClamAV is reachable', :env_required do
      before do
        skip 'ClamAV not available' unless clamav_available?
      end

      it 'scans a clean file and returns clean status' do
        clean_file = Tempfile.new('clean_test')
        clean_file.write('Hello, this is clean content.')
        clean_file.flush

        result = client.scan_file(clean_file.path)
        expect(result[:status]).to eq(:clean)
      ensure
        clean_file.close
        clean_file.unlink
      end
    end
  end

  describe '#fetch_version' do
    context 'when ClamAV is not reachable' do
      let(:client) { described_class.new(host: '192.0.2.1', port: 9999, timeout: 0.1, max_stream_bytes: 1024) }

      it 'returns nil without raising' do
        expect(client.fetch_version).to be_nil
      end
    end
  end

  private

  def clamav_available?
    TCPSocket.new(host, port).close
    true
  rescue StandardError
    false
  end
end
