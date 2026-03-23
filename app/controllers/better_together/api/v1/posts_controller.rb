# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # JSONAPI resource controller for posts
      # Provides API equivalent functionality to BetterTogether::PostsController
      class PostsController < BetterTogether::Api::ApplicationController
        # GET /api/v1/posts
        # Policy scope filters by:
        # - Privacy settings (public/private)
        # - Published status
        # - Blocked user exclusion
        def index
          super
        end

        # GET /api/v1/posts/:id
        # Authorization via PostPolicy:
        # - Creator/manager: always visible
        # - Blocked author: denied
        # - Otherwise: must be published + public
        def show
          super
        end

        # POST /api/v1/posts
        # Requires 'manage_platform' permission
        def create
          super
        end

        # PATCH/PUT /api/v1/posts/:id
        # Requires 'manage_platform' permission
        def update
          super
        end

        # DELETE /api/v1/posts/:id
        # Requires 'manage_platform' permission
        def destroy
          super
        end
      end
    end
  end
end
