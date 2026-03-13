# frozen_string_literal: true

module BetterTogether
  module Content
    # Imports or updates a mirrored Page record from a connected remote platform.
    class FederatedPageMirrorService
      def initialize(connection:, remote_attributes:, remote_id:, preserve_remote_uuid: false, source_updated_at: nil)
        @connection = connection
        @remote_attributes = remote_attributes.to_h.with_indifferent_access
        @remote_id = remote_id.to_s
        @preserve_remote_uuid = preserve_remote_uuid
        @source_updated_at = source_updated_at
      end

      def call
        authorize_mirroring!

        page = find_or_initialize_page
        assign_attributes(page)
        page.save!
        page
      end

      private

      attr_reader :connection, :remote_attributes, :remote_id, :preserve_remote_uuid, :source_updated_at

      def authorize_mirroring!
        result = ::BetterTogether::Content::FederatedContentAuthorizer.call(
          connection:,
          content_or_type: ::BetterTogether::Page,
          action: :mirror
        )

        return if result.allowed?

        raise ArgumentError, "page mirroring not authorized: #{result.reason}"
      end

      def find_or_initialize_page
        if preserve_remote_uuid? && uuid?(remote_id)
          existing = ::BetterTogether::Page.find_by(id: remote_id)
          return existing if existing

          ::BetterTogether::Page.new(id: remote_id)
        else
          ::BetterTogether::Page.find_or_initialize_by(platform: connection.source_platform, source_id: remote_id)
        end
      end

      def assign_attributes(page)
        page.assign_attributes(attributes_for(page))
      end

      def attributes_for(page)
        common_mirror_attributes(page).merge(
          layout: remote_attributes[:layout],
          template: remote_attributes[:template],
          meta_description: remote_attributes[:meta_description],
          keywords: remote_attributes[:keywords]
        )
      end

      def common_mirror_attributes(record)
        core_content_attributes(record).merge(mirror_tracking_attributes)
      end

      def core_content_attributes(record)
        {
          title: remote_attributes[:title],
          content: remote_attributes[:content],
          identifier: normalized_identifier(record),
          privacy: remote_attributes[:privacy].presence || 'public',
          published_at: remote_attributes[:published_at],
          creator_id: remote_attributes[:creator_id]
        }
      end

      def mirror_tracking_attributes
        {
          platform: connection.source_platform,
          source_id: preserve_remote_uuid? ? nil : remote_id,
          source_updated_at: normalized_source_updated_at,
          last_synced_at: Time.current
        }
      end

      def normalized_identifier(page)
        remote_attributes[:identifier].presence ||
          page.identifier.presence ||
          "federated-page-#{remote_id.parameterize.presence || SecureRandom.hex(6)}"
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
