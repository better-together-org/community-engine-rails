# frozen_string_literal: true

module BetterTogether
  module Mcp
    # MCP Tool to update an existing post (write tool)
    # Requires authentication and update permissions (manage_platform)
    class UpdatePostTool < ApplicationTool
      description 'Update the title, content, or privacy of an existing post'
      tags :authenticated

      arguments do
        required(:post_id).filled(:string).description('UUID of the post to update')
        optional(:title).filled(:string).description('New post title')
        optional(:content).filled(:string).description('New post content (supports markdown)')
        optional(:privacy).filled(:string).description('New privacy level: public or private')
      end

      # Update a post
      # @return [String] JSON with updated post or error
      def call(post_id:, **params)
        return auth_required_response unless current_user

        with_current_governed_agent do
          with_timezone_scope do
            post = BetterTogether::Post.find_by(id: post_id)
            return not_found_response unless post

            authorize post, :update?

            result = apply_updates_and_respond(post, params)
            log_invocation('update_post', { post_id: post_id }.merge(params.except(:content)), result.bytesize)
            result
          end
        end
      rescue Pundit::NotAuthorizedError
        JSON.generate({ error: 'Not authorized to update this post' })
      end

      private

      def auth_required_response
        JSON.generate({ error: 'Authentication required' })
      end

      def not_found_response
        JSON.generate({ error: 'Post not found' })
      end

      def apply_updates_and_respond(post, params)
        post.title = params[:title] if params.key?(:title)
        post.content = params[:content] if params.key?(:content)
        post.privacy = params[:privacy] if params.key?(:privacy)

        if post.save
          JSON.generate(success_response(post))
        else
          JSON.generate({ error: 'Validation failed', details: post.errors.full_messages })
        end
      end

      def success_response(post)
        {
          id: post.id,
          title: post.title,
          privacy: post.privacy,
          published_at: post.published_at&.iso8601,
          url: BetterTogether::Engine.routes.url_helpers.post_path(post, locale: I18n.locale)
        }
      end
    end
  end
end
