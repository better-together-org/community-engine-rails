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
          execute_clamav_scan(Configuration.build_client, blob)
        rescue ClamAvClient::ConnectionError => e
          failure_result('clamav_connection_error', e.message)
        rescue ClamAvClient::Error => e
          failure_result('clamav_scan_error', e.message)
        rescue StandardError => e
          failure_result(e.class.name, e.message)
        end

        def execute_clamav_scan(client, blob)
          scanner_version = client.fetch_version
          blob.open do |file|
            response = client.scan_file(file.path)
            return clean_result(scanner_version) if response.fetch(:status) == :clean

            infected_result(response.fetch(:signature_name), scanner_version)
          end
        end

        def clean_result(scanner_version = nil)
          Result.new(status: :clean, verdict: 'clean', scanner_name: 'clamav', scanner_version:)
        end

        def infected_result(signature_name, scanner_version = nil)
          Result.new(
            status: :infected, verdict: 'quarantined', scanner_name: 'clamav',
            signature_name:, scanner_version:
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
