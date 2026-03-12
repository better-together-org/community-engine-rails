# frozen_string_literal: true

module BetterTogether
  module Content
    # Answers whether a platform connection can mirror or publish a given CE content type.
    class FederatedContentAuthorizer
      CONTENT_TYPE_MAP = {
        'BetterTogether::Post' => 'posts',
        'BetterTogether::Page' => 'pages',
        'BetterTogether::Event' => 'events',
        'posts' => 'posts',
        'pages' => 'pages',
        'events' => 'events',
        'post' => 'posts',
        'page' => 'pages',
        'event' => 'events'
      }.freeze

      Result = Struct.new(
        :connection,
        :action,
        :requested_type,
        :normalized_type,
        :allowed,
        :reason,
        keyword_init: true
      ) do
        def allowed?
          allowed
        end
      end

      def self.call(connection:, content_or_type:, action: :mirror)
        new(connection:, content_or_type:, action:).call
      end

      def initialize(connection:, content_or_type:, action: :mirror)
        @connection = connection
        @content_or_type = content_or_type
        @action = action.to_s
      end

      def call
        return result(false, 'connection is required') unless connection
        return result(false, 'unsupported action') unless %w[mirror publish_back].include?(action)

        normalized_type = normalize_content_type(content_or_type)
        return result(false, 'unsupported content type', normalized_type:) unless normalized_type

        return result(false, 'connection is not active', normalized_type:) unless connection.active?

        if action == 'mirror'
          allowed = connection.mirrored_content_enabled? && connection.allows_content_type?(normalized_type)
          return result(allowed, allowed ? 'allowed' : 'content mirroring not enabled for type', normalized_type:)
        end

        allowed = connection.publish_back_enabled? && connection.allows_content_type?(normalized_type)
        result(allowed, allowed ? 'allowed' : 'publish back not enabled for type', normalized_type:)
      end

      private

      attr_reader :connection, :content_or_type, :action

      def normalize_content_type(content_or_type)
        key =
          if content_or_type.is_a?(Class)
            content_or_type.name
          elsif content_or_type.respond_to?(:class) && !content_or_type.is_a?(String) && !content_or_type.is_a?(Symbol)
            content_or_type.class.name
          else
            content_or_type.to_s
          end

        CONTENT_TYPE_MAP[key]
      end

      def result(allowed, reason, normalized_type: normalize_content_type(content_or_type))
        Result.new(
          connection:,
          action:,
          requested_type: content_or_type,
          normalized_type:,
          allowed:,
          reason:
        )
      end
    end
  end
end
