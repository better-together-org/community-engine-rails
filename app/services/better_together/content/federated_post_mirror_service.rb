# frozen_string_literal: true

module BetterTogether
  module Content
    # Imports or updates a mirrored Post record from a connected remote platform.
    class FederatedPostMirrorService
      def initialize(connection:, remote_attributes:, remote_id:, preserve_remote_uuid: false, source_updated_at: nil)
        @connection = connection
        @remote_attributes = remote_attributes.to_h.with_indifferent_access
        @remote_id = remote_id.to_s
        @preserve_remote_uuid = preserve_remote_uuid
        @source_updated_at = source_updated_at
      end

      def call
        authorize_mirroring!

        post = find_or_initialize_post
        assign_attributes(post)
        post.save!
        post
      end

      private

      attr_reader :connection, :remote_attributes, :remote_id, :preserve_remote_uuid, :source_updated_at

      def authorize_mirroring!
        result = ::BetterTogether::Content::FederatedContentAuthorizer.call(
          connection:,
          content_or_type: ::BetterTogether::Post,
          action: :mirror
        )

        return if result.allowed?

        raise ArgumentError, "post mirroring not authorized: #{result.reason}"
      end

      def find_or_initialize_post
        if effective_preserve_remote_uuid? && uuid?(remote_id)
          # 1. Already mirrored with the same UUID — most common repeat-sync path.
          existing = ::BetterTogether::Post.find_by(id: remote_id)
          return existing if existing

          # 2. Previously mirrored via the source_id path (e.g. before preserve_remote_uuid
          #    was enabled on this connection) — prevents duplicate record creation.
          existing = ::BetterTogether::Post.find_by(
            platform: connection.target_platform, source_id: remote_id
          )
          return existing if existing

          ::BetterTogether::Post.new(id: remote_id)
        else
          ::BetterTogether::Post.find_or_initialize_by(platform: connection.target_platform, source_id: remote_id)
        end
      end

      def assign_attributes(post)
        post.assign_attributes(attributes_for(post))
      end

      def attributes_for(post)
        {
          title: remote_attributes[:title],
          content: remote_attributes[:content],
          identifier: normalized_identifier(post),
          privacy: remote_attributes[:privacy].presence || 'public',
          published_at: remote_attributes[:published_at],
          creator_id: remote_attributes[:creator_id],
          platform: connection.target_platform
        }.merge(post_sync_attributes)
      end

      def post_sync_attributes
        {
          source_id: effective_preserve_remote_uuid? ? nil : remote_id,
          source_updated_at: normalized_source_updated_at,
          last_synced_at: Time.current
        }
      end

      def normalized_identifier(post)
        # Preserve the existing identifier on a repeat sync — avoids churn on slug/history.
        return post.identifier if post.persisted?

        base = remote_attributes[:identifier].presence ||
               "federated-post-#{remote_id.parameterize.presence || SecureRandom.hex(6)}"
        identifier_or_namespaced(::BetterTogether::Post, base, post.id)
      end

      # Returns +base+ unchanged when no other record claims it; otherwise prepends the
      # source platform identifier to prevent a uniqueness validation failure on ingest.
      def identifier_or_namespaced(model_class, base, exclude_id)
        return base unless identifier_taken?(model_class, base, exclude_id)

        source_slug = connection.source_platform.identifier.to_s.parameterize.presence || 'remote'
        "#{source_slug}-#{base}"
      end

      def identifier_taken?(model_class, identifier, exclude_id)
        scope = model_class.where(identifier:)
        scope = scope.where.not(id: exclude_id) if exclude_id.present?
        scope.exists?
      end

      def normalized_source_updated_at
        return source_updated_at if source_updated_at.present?
        return remote_attributes[:updated_at] if remote_attributes[:updated_at].present?

        Time.current
      end

      def preserve_remote_uuid?
        preserve_remote_uuid
      end

      def effective_preserve_remote_uuid?
        preserve_remote_uuid? && !connection.target_platform.local_hosted?
      end

      def uuid?(value)
        /\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i.match?(value.to_s)
      end
    end
  end
end
