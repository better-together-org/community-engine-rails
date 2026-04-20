# frozen_string_literal: true

module BetterTogether
  # CRUD for BetterTogether::Post
  class PostsController < FriendlyResourceController
    def create
      BetterTogether::Authorship.with_creator(helpers.current_person) do
        super
      end
    end

    def update
      BetterTogether::Authorship.with_creator(helpers.current_person) do
        super
      end
    end

    protected

    def resource_class
      ::BetterTogether::Post
    end

    def resource_collection
      @resources ||= policy_scope(resource_class)
                     .includes(*resource_class.card_render_includes)

      instance_variable_set("@#{resource_name(plural: true)}", @resources)
    end

    def resource_params
      super.tap do |attrs|
        attrs[:creator_id] = helpers.current_person&.id if action_name == 'create'
      end
    end
  end
end
