# frozen_string_literal: true

module BetterTogether
  module Mcp
    # MCP Tool to search posts with privacy-aware filtering
    # Automatically excludes:
    # - Private posts from other users
    # - Posts from blocked users
    # - Unpublished posts
    class SearchPostsTool < ApplicationTool
      description 'Search published posts accessible to the current user, respecting privacy settings and blocks'

      arguments do
        required(:query)
          .filled(:string)
          .description('Search query to match against post titles and content')
        optional(:limit)
          .filled(:integer)
          .description('Maximum number of results to return (default: 20)')
      end

      # Search posts with authorization and privacy filtering
      # @param query [String] The search query
      # @param limit [Integer] Maximum results (default: 20)
      # @return [String] JSON array of post objects
      def call(query:, limit: 20)
        # Execute in user's timezone for consistent date/time formatting
        with_timezone_scope do
          # Use policy_scope to automatically filter by:
          # - Privacy settings (public posts, or own private posts)
          # - Published status
          # - Blocked users (excluded automatically by PostPolicy::Scope)
          posts = policy_scope(BetterTogether::Post)
                  .i18n
                  .joins(:string_translations)
                  .where(
                    'mobility_string_translations.value ILIKE ? AND mobility_string_translations.key IN (?)',
                    "%#{query}%",
                    %w[title]
                  )
                  .order(published_at: :desc)
                  .limit([limit, 100].min) # Cap at 100 to prevent abuse

          # Serialize posts to JSON
          JSON.generate(
            posts.map { |post| serialize_post(post) }
          )
        end
      end

      private

      # Serialize a post to a hash
      # @param post [BetterTogether::Post] The post to serialize
      # @return [Hash] Serialized post data
      def serialize_post(post)
        {
          id: post.id,
          title: post.title,
          excerpt: post.content.to_plain_text.truncate(200),
          published_at: post.published_at&.iso8601,
          creator_name: post.creator&.name,
          privacy: post.privacy,
          url: "/posts/#{post.slug}"
        }
      end
    end
  end
end
