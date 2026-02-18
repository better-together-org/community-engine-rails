# frozen_string_literal: true

module BetterTogether
  module Mcp
    # MCP Tool to get a specific post with privacy-aware access
    # Returns full post content including excerpt and metadata
    class GetPostTool < ApplicationTool
      description 'Get a specific published post by ID, respecting privacy settings and blocks'

      arguments do
        required(:post_id)
          .filled(:string)
          .description('The UUID of the post to retrieve')
      end

      # Get post details with authorization
      # @param post_id [String] The post UUID
      # @return [String] JSON object with post details
      def call(post_id:)
        with_timezone_scope do
          post = policy_scope(BetterTogether::Post).find_by(id: post_id)

          unless post
            result = JSON.generate({ error: 'Post not found or not accessible' })
            log_invocation('get_post', { post_id: post_id }, result.bytesize)
            return result
          end

          result = JSON.generate(serialize_post_detail(post))
          log_invocation('get_post', { post_id: post_id }, result.bytesize)
          result
        end
      end

      private

      def serialize_post_detail(post)
        post_attributes(post).merge(post_metadata(post))
      end

      def post_attributes(post)
        {
          id: post.id,
          title: post.title,
          content: post.content.to_s,
          excerpt: post.content.to_plain_text.truncate(
            Rails.application.config.mcp.excerpt_length
          ),
          slug: post.slug,
          privacy: post.privacy
        }
      end

      def post_metadata(post)
        {
          published_at: post.published_at&.iso8601,
          creator_name: post.creator&.name,
          url: BetterTogether::Engine.routes.url_helpers.post_path(post, locale: I18n.locale)
        }
      end
    end
  end
end
