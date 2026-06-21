# frozen_string_literal: true

module BetterTogether
  module Mcp
    # MCP Tool to publish or unpublish an existing post (write tool)
    # Requires authentication and update permissions (manage_platform)
    class PublishPostTool < ApplicationTool
      description 'Publish or unpublish a post by setting or clearing its published_at timestamp'
      tags :authenticated

      arguments do
        required(:post_id).filled(:string).description('UUID of the post to publish or unpublish')
        required(:publish).filled(:bool).description('true to publish immediately, false to revert to draft')
      end

      # Publish or unpublish a post
      # @return [String] JSON with updated post or error
      def call(post_id:, publish:)
        return auth_required_response unless current_user

        with_current_governed_agent do
          with_timezone_scope do
            post = BetterTogether::Post.find_by(id: post_id)
            return not_found_response unless post

            authorize post, :update?
            toggle_publication(post, publish, post_id)
          end
        end
      rescue Pundit::NotAuthorizedError
        JSON.generate({ error: 'Not authorized to update this post' })
      end

      private

      def toggle_publication(post, publish, post_id)
        post.published_at = publish ? Time.current : nil
        result = save_or_error(post, publish)
        log_invocation('publish_post', { post_id: post_id, publish: publish }, result.bytesize)
        result
      end

      def save_or_error(post, publish)
        if post.save
          JSON.generate(success_response(post, publish))
        else
          JSON.generate({ error: 'Validation failed', details: post.errors.full_messages })
        end
      end

      def auth_required_response
        JSON.generate({ error: 'Authentication required' })
      end

      def not_found_response
        JSON.generate({ error: 'Post not found' })
      end

      def success_response(post, published)
        {
          id: post.id,
          title: post.title,
          status: published ? 'published' : 'draft',
          published_at: post.published_at&.iso8601,
          url: BetterTogether::Engine.routes.url_helpers.post_path(post, locale: I18n.locale)
        }
      end
    end
  end
end
