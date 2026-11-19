# frozen_string_literal: true

module BetterTogether
  module Storage
    # Writes, reads and deletes one small probe object through a StorageConfiguration's service.
    # Never raises: a failure is returned as a short message built from the error class, because
    # provider messages can echo endpoints and key ids.
    class ConnectionTest
      Result = Struct.new(:ok, :message) do
        alias_method :ok?, :ok
      end

      PAYLOAD = 'better-together-connection-test'
      TIMEOUT = 10

      def initialize(configuration)
        @configuration = configuration
      end

      def call
        key = "better-together-connection-test/#{SecureRandom.uuid}"
        service = build_service
        Timeout.timeout(TIMEOUT) { probe(service, key) }
      rescue Timeout::Error
        Result.new(false, 'timeout')
      rescue StandardError => e
        Result.new(false, failure_message(e))
      ensure
        cleanup(service, key)
      end

      private

      attr_reader :configuration

      def build_service
        ActiveStorage::Service.configure(:connection_test, { connection_test: configuration.to_active_storage_config })
      end

      def probe(service, key)
        service.upload(key, StringIO.new(PAYLOAD), checksum: OpenSSL::Digest::MD5.base64digest(PAYLOAD))
        return Result.new(false, 'read_back_mismatch') unless service.download(key) == PAYLOAD

        Result.new(true, 'ok')
      end

      def cleanup(service, key)
        service&.delete(key) if key
      rescue StandardError
        nil
      end

      def failure_message(error)
        error.class.name.demodulize.underscore.truncate(80)
      end
    end
  end
end
