# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ContentSecurity::Scanner, type: :service do
  let(:blob) do
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new('test file content'),
      filename: "test-#{SecureRandom.hex(4)}.txt",
      content_type: 'text/plain'
    )
  end

  def build_malware_scanning_config(engine:)
    ms = ActiveSupport::OrderedOptions.new
    ms.enabled = true
    ms.engine = engine
    ms.host = '127.0.0.1'
    ms.port = 3310
    ms.timeout = 1
    ms.max_stream_bytes = 5.megabytes
    ms
  end

  def with_scanning_enabled(engine: 'clamav')
    original = BetterTogether.content_security
    config = ActiveSupport::OrderedOptions.new
    config.malware_scanning = build_malware_scanning_config(engine: engine)
    BetterTogether.content_security = config
    yield
  ensure
    BetterTogether.content_security = original
  end

  def with_scanning_disabled(&)
    original = BetterTogether.content_security
    config = ActiveSupport::OrderedOptions.new
    malware_scanning = ActiveSupport::OrderedOptions.new
    malware_scanning.enabled = false
    config.malware_scanning = malware_scanning
    BetterTogether.content_security = config
    yield
  ensure
    BetterTogether.content_security = original
  end

  describe '.scan_blob' do
    context 'when scanning is disabled' do
      it 'returns a clean result without contacting the scanner' do
        with_scanning_disabled do
          result = described_class.scan_blob(blob)

          expect(result.status).to eq(:clean)
          expect(result.verdict).to eq('clean')
          expect(result.scanner_name).to eq('disabled')
        end
      end
    end

    context 'when engine is unsupported' do
      it 'returns an error result for an unknown engine' do
        with_scanning_enabled(engine: 'unknown_engine') do
          result = described_class.scan_blob(blob)

          expect(result.status).to eq(:error)
          expect(result.verdict).to eq('review_required')
          expect(result.error_class).to eq('unsupported_engine')
          expect(result.error_summary).to include('unknown_engine')
        end
      end
    end

    context 'when engine is clamav' do
      let(:clamav_client) { instance_double(BetterTogether::ContentSecurity::ClamAvClient) }

      before do
        allow(BetterTogether::ContentSecurity::ClamAvClient).to receive(:new).and_return(clamav_client)
        allow(clamav_client).to receive(:fetch_version).and_return('ClamAV 1.0.0/daily.123')
      end

      context 'when the file is clean' do
        before do
          allow(clamav_client).to receive(:scan_file).and_return(
            { status: :clean, signature_name: nil, raw_response: 'stream: OK' }
          )
        end

        it 'returns a clean result' do
          with_scanning_enabled do
            result = described_class.scan_blob(blob)

            expect(result.status).to eq(:clean)
            expect(result.verdict).to eq('clean')
            expect(result.scanner_name).to eq('clamav')
            expect(result.scanner_version).to eq('ClamAV 1.0.0/daily.123')
          end
        end
      end

      context 'when the file is infected' do
        before do
          allow(clamav_client).to receive(:scan_file).and_return(
            { status: :infected, signature_name: 'Eicar-Test-Signature', raw_response: 'stream: Eicar-Test-Signature FOUND' }
          )
        end

        it 'returns an infected result with the signature name' do
          with_scanning_enabled do
            result = described_class.scan_blob(blob)

            expect(result.status).to eq(:infected)
            expect(result.verdict).to eq('quarantined')
            expect(result.signature_name).to eq('Eicar-Test-Signature')
            expect(result.scanner_name).to eq('clamav')
          end
        end
      end

      context 'when ClamAV raises a ConnectionError' do
        before do
          allow(clamav_client).to receive(:scan_file).and_raise(
            BetterTogether::ContentSecurity::ClamAvClient::ConnectionError, 'connection refused'
          )
        end

        it 'returns a review_required error result' do
          with_scanning_enabled do
            result = described_class.scan_blob(blob)

            expect(result.status).to eq(:error)
            expect(result.verdict).to eq('review_required')
            expect(result.error_class).to eq('clamav_connection_error')
            expect(result.error_summary).to eq('connection refused')
          end
        end
      end

      context 'when ClamAV raises a generic Error' do
        before do
          allow(clamav_client).to receive(:scan_file).and_raise(
            BetterTogether::ContentSecurity::ClamAvClient::Error, 'scan failed'
          )
        end

        it 'returns a review_required error result' do
          with_scanning_enabled do
            result = described_class.scan_blob(blob)

            expect(result.status).to eq(:error)
            expect(result.verdict).to eq('review_required')
            expect(result.error_class).to eq('clamav_scan_error')
          end
        end
      end

      context 'when an unexpected StandardError occurs' do
        before do
          allow(clamav_client).to receive(:scan_file).and_raise(
            RuntimeError, 'something unexpected'
          )
        end

        it 'returns a review_required error result with the exception class name' do
          with_scanning_enabled do
            result = described_class.scan_blob(blob)

            expect(result.status).to eq(:error)
            expect(result.verdict).to eq('review_required')
            expect(result.error_class).to eq('RuntimeError')
            expect(result.error_summary).to eq('something unexpected')
          end
        end
      end
    end
  end

  describe 'Scanner::Result' do
    it 'is a keyword-initialized struct' do
      result = described_class::Result.new(
        status: :clean,
        verdict: 'clean',
        scanner_name: 'test'
      )

      expect(result.status).to eq(:clean)
      expect(result.verdict).to eq('clean')
      expect(result.scanner_name).to eq('test')
      expect(result.signature_name).to be_nil
      expect(result.error_class).to be_nil
    end
  end
end
