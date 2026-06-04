# frozen_string_literal: true

module BetterTogether
  # CRUD for BetterTogether::Post
  class PostsController < FriendlyResourceController
    def index
      @posts = PostsSearchFilter.call(
        resource_class:,
        relation: resource_collection,
        params: filter_params
      )
      @categories = ::BetterTogether::Category.where(categorizable_type: 'BetterTogether::Post')
                                              .order(:name)
    end

    protected

    def resource_class
      ::BetterTogether::Post
    end

    def resource_params
      super.tap do |attrs|
        attrs[:creator_id] = helpers.current_person&.id if action_name == 'create'
      end
    end

    private

    def filter_params
      params.permit(:q, :order_by, :per_page, :page, :privacy, category_ids: [])
    end
  end
end
