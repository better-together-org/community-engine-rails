# frozen_string_literal: true

module BetterTogether
  # CRUD for BetterTogether::Post
  class PostsController < FriendlyResourceController
    protected

    def resource_class
      ::BetterTogether::Post
    end

    def resource_params
      super.tap do |attrs|
        attrs[:creator_id] = helpers.current_person&.id if action_name == 'create'
      end
    end
  end
end
