# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # JSONAPI resource controller for uploads
      # Scoped to creator's own uploads via UploadPolicy::Scope
      class UploadsController < BetterTogether::Api::ApplicationController
        def index
          super
        end

        def show
          super
        end

        def create
          super
        end

        def update
          super
        end

        def destroy
          super
        end
      end
    end
  end
end
