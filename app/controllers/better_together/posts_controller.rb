# frozen_string_literal: true

module BetterTogether
  # CRUD for BetterTogether::Post
  class PostsController < FriendlyResourceController
    def index
      load_posts
      load_categories
      load_authors
    end

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
                     .includes(*post_includes)

      instance_variable_set("@#{resource_name(plural: true)}", @resources)
    end

    def post_includes
      resource_class.card_render_includes.reject do |entry|
        entry.is_a?(Hash) && entry[:contributions]
      end
    end

    def post_index_includes
      post_includes + [{ categories: :string_translations }]
    end

    def resource_params
      super.tap do |attrs|
        attrs[:creator_id] = helpers.current_person&.id if action_name == 'create'
      end
    end

    private

    def filter_params
      params.permit(:q, :order_by, :per_page, :page, :privacy, category_ids: [], author_ids: [])
    end

    def load_posts
      @posts = PostsSearchFilter.call(
        relation: policy_scope(resource_class),
        params: filter_params
      ).with_translations
                                .includes(post_index_includes)
                                .preload(contributions: :author)
    end

    def load_categories
      post_category_ids = ::BetterTogether::Categorization
                          .where(categorizable_type: 'BetterTogether::Post')
                          .select(:category_id)

      @categories = ::BetterTogether::Category
                    .where(id: post_category_ids)
                    .with_translations
                    .to_a
                    .sort_by { |category| category.name.to_s.downcase }
    end

    def load_authors
      author_ids = ::BetterTogether::Authorship
                   .where(
                     authorable_type: resource_class.name,
                     author_type: 'BetterTogether::Person',
                     role: ::BetterTogether::Authorship::AUTHOR_ROLE
                   )
                   .select(:author_id)
                   .distinct

      @authors = ::BetterTogether::Person
                 .where(id: author_ids)
                 .i18n
                 .order(:name)
    end

    def permitted_attributes
      [
        :privacy,
        :published_at,
        :contributors_display_visibility,
        *resource_class.localized_attribute_list,
        *resource_class.extra_permitted_attributes
      ]
    end
  end
end
