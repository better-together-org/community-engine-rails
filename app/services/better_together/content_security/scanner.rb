# frozen_string_literal: true

module BetterTogether
  module ContentSecurity
    # Dispatches blob scans to the configured engine and normalises results into a Scanner::Result.
    class Scanner
      Result = Struct.new(
        :status,
        :verdict,
        :scanner_name,
        :scanner_version,
        :signature_name,
        :error_class,
        :error_summary,
        keyword_init: true
      )

      class << self
        def scan_blob(blob)
          return disabled_result unless Configuration.enabled?

          case Configuration.engine
          when 'clamav'
            scan_with_clamav(blob)
          else
            Result.new(
              status: :error,
              verdict: 'review_required',
              scanner_name: Configuration.engine.presence || 'unknown',
              error_class: 'unsupported_engine',
              error_summary: "Unsupported malware scanner engine: #{Configuration.engine.inspect}"
            )
          end
        end

        private

        def disabled_result
          Result.new(
            status: :clean,
            verdict: 'clean',
            scanner_name: 'disabled'
          )
        end

        def scan_with_clamav(blob)
          execute_clamav_scan(build_clamav_client, blob)
        rescue ClamAvClient::ConnectionError => e
          failure_result('clamav_connection_error', e.message)
        rescue ClamAvClient::Error => e
          failure_result('clamav_scan_error', e.message)
        rescue StandardError => e
          failure_result(e.class.name, e.message)
        end

        def execute_clamav_scan(client, blob)
          blob.open do |file|
            response = client.scan_file(file.path)
            return clean_result if response.fetch(:status) == :clean

            infected_result(response.fetch(:signature_name))
          end
        end

        def build_clamav_client
          ClamAvClient.new(
            host: Configuration.host,
            port: Configuration.port,
            timeout: Configuration.timeout,
            max_stream_bytes: Configuration.max_stream_bytes
          )
        end

        def clean_result
          Result.new(
            status: :clean,
            verdict: 'clean',
            scanner_name: 'clamav'
          )
        end

        def infected_result(signature_name)
          Result.new(
            status: :infected,
            verdict: 'quarantined',
            scanner_name: 'clamav',
            signature_name: signature_name
          )
        end

        def failure_result(error_class, error_summary)
          Result.new(
            status: :error,
            verdict: 'review_required',
            scanner_name: 'clamav',
            error_class: error_class,
            error_summary: error_summary
          )
        end
      end
    end
  end
end
