# frozen_string_literal: true

module BetterTogether
  module Federation
    # Shared identifier fallback strategy for mirrored records in shared databases.
    module MirroredIdentifierResolution
      private

      def mirrored_identifier_for(content_type:, remote_identifier:, remote_id:, model_class: nil, exclude_id: nil)
        _ = model_class
        _ = exclude_id

        BetterTogether::Federation::MirroredIdentifier.canonical(
          source_platform: connection.source_platform,
          remote_identifier:,
          remote_id:,
          content_type:
        )
      end

      def existing_identifier_conflict_for(model_class, remote_identifier:, remote_id:, content_type:, exclude_id: nil)
        identifier = mirrored_identifier_for(
          content_type:,
          remote_identifier:,
          remote_id:,
          model_class:,
          exclude_id:
        )

        scope = model_class.where(identifier:)
        scope = scope.where.not(id: exclude_id) if exclude_id.present?
        scope.first
      end

      def identifier_or_namespaced(model_class, base, exclude_id)
        identifier_candidates(base).find do |candidate|
          !identifier_taken?(model_class, candidate, exclude_id)
        end
      end

      def identifier_taken?(model_class, identifier, exclude_id)
        scope = model_class.where(identifier:)
        scope = scope.where.not(id: exclude_id) if exclude_id.present?
        scope.exists?
      end

      def identifier_candidates(base)
        source_slug = platform_identifier_slug(connection.source_platform, fallback: 'remote')
        target_slug = platform_identifier_slug(connection.target_platform, fallback: 'local')

        [
          base,
          "#{source_slug}-#{base}",
          "#{target_slug}-#{source_slug}-#{base}"
        ]
      end

      def platform_identifier_slug(platform, fallback:)
        platform.identifier.to_s.parameterize.presence || fallback
      end
    end
  end
end
