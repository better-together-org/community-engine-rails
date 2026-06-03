# frozen_string_literal: true

module BetterTogether
  module Federation
    module Transport
      # Chooses the transport path for federation pulls based on connection locality.
      class TransportResolver
        def self.call(connection:)
          new(connection:).call
        end

        def initialize(connection:)
          @connection = connection
        end

        def call
          return same_instance_resolution if same_instance?

          remote_http_resolution
        end

        private

        attr_reader :connection

        def same_instance?
          connection.source_platform.local_hosted? && connection.target_platform.local_hosted?
        end

        def same_instance_resolution
          Resolution.new(:same_instance, DirectAdapter)
        end

        def remote_http_resolution
          Resolution.new(:remote_http, HttpAdapter)
        end
      end
    end
  end
end
