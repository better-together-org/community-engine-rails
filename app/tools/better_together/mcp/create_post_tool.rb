# frozen_string_literal: true

module BetterTogether
  module Mcp
    # MCP Tool to create or draft a post (write tool)
    # Requires authentication and post creation permissions
    class CreatePostTool < ApplicationTool
      description 'Create a new post with the specified content, optionally as a draft'

      arguments do
        required(:title).filled(:string).description('Post title')
        required(:content).filled(:string).description('Post content (supports markdown)')
        optional(:privacy).filled(:string).description('Privacy level: public or private (default: public)')
        optional(:publish).filled(:bool).description('Publish immediately (default: false, saves as draft)')
      end

      # Create a post
      # @return [String] JSON with created post or error
      def call(**params)
        return auth_required_response unless current_user

        with_timezone_scope do
          post = build_post(params)
          authorize post, :create?

          result = save_and_respond(post, params)
          log_invocation('create_post', params.except(:content), result.bytesize)
          result
        end
      rescue Pundit::NotAuthorizedError
        JSON.generate({ error: 'Not authorized to create posts' })
      end

      private

      def auth_required_response
        JSON.generate({ error: 'Authentication required' })
      end

      def build_post(params)
        BetterTogether::Post.new(
          title: params[:title],
          content: params[:content],
          privacy: params[:privacy] || 'public',
          published_at: params[:publish] ? Time.current : nil,
          creator: current_user.person
        )
      end

      def save_and_respond(post, params)
        if post.save
          JSON.generate(success_response(post, params[:publish]))
        else
          JSON.generate({ error: 'Validation failed', details: post.errors.full_messages })
        end
      end

      def success_response(post, published)
        {
          id: post.id,
          title: post.title,
          privacy: post.privacy,
          status: published ? 'published' : 'draft',
          published_at: post.published_at&.iso8601,
          url: BetterTogether::Engine.routes.url_helpers.post_path(post, locale: I18n.locale)
        }
      end
    end
  end
end
