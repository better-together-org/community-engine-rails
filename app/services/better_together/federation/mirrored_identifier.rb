# frozen_string_literal: true

require 'digest'

module BetterTogether
  module Federation
    # Deterministic identifier builder for mirrored content imported from a remote platform.
    module MirroredIdentifier
      module_function

      def canonical(source_platform:, remote_identifier:, remote_id:, content_type:)
        source_slug = BetterTogether::FriendlySlug.normalize_slug_preserving_namespace(source_platform&.identifier).presence || 'remote'
        base = remote_identifier_base(remote_identifier:, remote_id:, content_type:)

        "#{source_slug}--#{base}"
      end

      def remote_identifier_base(remote_identifier:, remote_id:, content_type:)
        normalized_remote_identifier = BetterTogether::FriendlySlug.normalize_slug_preserving_namespace(remote_identifier)
        return normalized_remote_identifier if normalized_remote_identifier.present?

        "federated-#{content_type}-#{fallback_remote_key(remote_id)}"
      end

      def fallback_remote_key(remote_id)
        normalized_remote_id = BetterTogether::FriendlySlug.normalize_slug_preserving_namespace(remote_id)
        return normalized_remote_id if normalized_remote_id.present?

        Digest::SHA256.hexdigest(remote_id.to_s)[0, 12]
      end
    end
  end
end
