# frozen_string_literal: true

module BetterTogether
  module ContentSecurity
    # Reads malware scanning settings from BetterTogether.content_security.malware_scanning config.
    class Configuration
      class << self
        def enabled?
          malware_scanning.enabled == true
        end

        def engine
          malware_scanning.engine.to_s
        end

        def fail_mode
          malware_scanning.fail_mode.to_s.presence || 'hold_until_clean'
        end

        def host
          malware_scanning.host.to_s
        end

        def port
          malware_scanning.port.to_i
        end

        def timeout
          malware_scanning.timeout.to_f.positive? ? malware_scanning.timeout.to_f : 10.0
        end

        def max_stream_bytes
          value = malware_scanning.max_stream_bytes.to_i
          value.positive? ? value : 25.megabytes
        end

        def enabled_for_surface?(surface)
          enabled_surfaces.include?(surface.to_s)
        end

        def enabled_surfaces
          Array(malware_scanning.enabled_surfaces).map(&:to_s)
        end

        def build_client
          ClamAvClient.new(
            host: host,
            port: port,
            timeout: timeout,
            max_stream_bytes: max_stream_bytes
          )
        end

        private

        def malware_scanning
          BetterTogether.content_security.malware_scanning
        end
      end
    end
  end
end
