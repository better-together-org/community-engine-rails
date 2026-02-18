# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # JSONAPI resource controller for pages
      class PagesController < BetterTogether::Api::ApplicationController
        # GET /api/v1/pages
        # Policy scope: managers see all, authors see own + published,
        # others see published + public only
        def index
          super
        end

        # GET /api/v1/pages/:id
        def show
          super
        end

        # POST /api/v1/pages
        def create
          super
        end

        # PATCH /api/v1/pages/:id
        def update
          super
        end

        # DELETE /api/v1/pages/:id
        def destroy
          super
        end
      end
    end
  end
end
