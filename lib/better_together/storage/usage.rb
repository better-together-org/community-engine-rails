# frozen_string_literal: true

module BetterTogether
  module Storage
    # Bytes actually stored on a platform's own storage service, counted from the blobs stamped with
    # that service. The quota ledger charges owners (people, communities, platforms); this is the
    # bucket-side figure to reconcile it against and to check a platform's storage allowance.
    module Usage
      module_function

      def bytes_for(configuration)
        return 0 unless configuration

        ActiveStorage::Blob.where(service_name: configuration.storage_key).sum(:byte_size)
      end

      def blob_count_for(configuration)
        return 0 unless configuration

        ActiveStorage::Blob.where(service_name: configuration.storage_key).count
      end

      # Bytes on the platform's active service, or nil when the platform uses the shared default.
      def bytes_for_platform(platform)
        config = platform&.active_storage_configuration
        config && bytes_for(config)
      end

      # True when a new upload of `incoming` bytes still fits the allowance (nil allowance is unlimited).
      def within_allowance?(platform, incoming:, allowance_bytes:)
        return true if allowance_bytes.nil?

        (bytes_for_platform(platform) || 0) + incoming.to_i <= allowance_bytes.to_i
      end
    end
  end
end
