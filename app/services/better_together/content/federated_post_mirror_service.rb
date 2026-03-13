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
        if preserve_remote_uuid? && uuid?(remote_id)
          existing = ::BetterTogether::Post.find_by(id: remote_id)
          return existing if existing

          ::BetterTogether::Post.new(id: remote_id)
        else
          ::BetterTogether::Post.find_or_initialize_by(platform: connection.source_platform, source_id: remote_id)
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
          platform: connection.source_platform,
          source_id: preserve_remote_uuid? ? nil : remote_id,
          source_updated_at: normalized_source_updated_at,
          last_synced_at: Time.current
        }
      end

      def normalized_identifier(post)
        remote_attributes[:identifier].presence ||
          post.identifier.presence ||
          "federated-post-#{remote_id.parameterize.presence || SecureRandom.hex(6)}"
      end

      def normalized_source_updated_at
        return source_updated_at if source_updated_at.present?
        return remote_attributes[:updated_at] if remote_attributes[:updated_at].present?

        Time.current
      end

      def preserve_remote_uuid?
        preserve_remote_uuid
      end

      def uuid?(value)
        /\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i.match?(value.to_s)
      end
    end
  end
end
