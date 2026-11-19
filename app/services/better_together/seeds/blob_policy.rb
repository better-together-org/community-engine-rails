# frozen_string_literal: true

module BetterTogether
  module Seeds
    # Size limits for packet files. The 10 MB cap on YAML stays; blobs get their own, larger
    # per-file cap and a packet-wide cap. Override with BETTER_TOGETHER_SEED_BLOB_MAX_BYTES,
    # BETTER_TOGETHER_SEED_PACKET_MAX_BYTES and BETTER_TOGETHER_SEED_ARCHIVE_MAX_BYTES.
    module BlobPolicy
      module_function

      def max_blob_bytes
        Integer(ENV.fetch('BETTER_TOGETHER_SEED_BLOB_MAX_BYTES', 100.megabytes))
      end

      def max_packet_bytes
        Integer(ENV.fetch('BETTER_TOGETHER_SEED_PACKET_MAX_BYTES', 2.gigabytes))
      end

      def max_archive_bytes
        Integer(ENV.fetch('BETTER_TOGETHER_SEED_ARCHIVE_MAX_BYTES', 2.gigabytes))
      end
    end
  end
end
