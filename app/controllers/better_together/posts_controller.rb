# frozen_string_literal: true

module BetterTogether
  # CRUD for BetterTogether::Post
  # rubocop:disable Metrics/ClassLength
  class PostsController < FriendlyResourceController
    include PostsIndexPreload
    include ChecksRequiredAgreements

    # Prepended so this runs before the inherited :authorize_resource
    # before_action — otherwise Pundit's plain 404 (via authorize_resource's
    # local rescue) wins first and this friendlier redirect never fires.
    prepend_before_action :check_content_publishing_agreement, only: %i[new create]

    skip_before_action :resource_collection, only: :index

    def index
      @available_view_types = %w[card list table calendar map]
      @view_type = view_preference('index_view', default: 'card', allowed: @available_view_types)
      load_posts
      load_categories
      load_authors
    end

    def create
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
        attrs[:community_id] = community_context&.id if action_name == 'create' && attrs[:community_id].blank?
      end
    end

    def resource_instance(attrs = {})
      @resource ||= resource_class.new
      @resource.assign_attributes(attrs) if attrs.present?
      @resource.community_id ||= community_context&.id

      instance_variable_set("@#{resource_name}", @resource)
      @resource
    end

    private

    def filter_params
      params.permit(:q, :order_by, :per_page, :page, :privacy, category_ids: [], author_ids: [])
    end

    def load_posts
      search_params = filter_params
      search_params[:community_ids] = scoped_community_ids

      @posts = PostsSearchFilter.call(
        relation: policy_scoped_resources,
        params: search_params
      ).with_translations
                                .includes(post_index_includes)
    end

    def load_categories
      @categories = ::BetterTogether::Category.used_by(policy_scoped_resources)
    end

    # Memoized so load_categories reuses load_posts' policy_scope(resource_class)
    # call instead of re-running the policy scope's query a second time on
    # every index request.
    def policy_scoped_resources
      @policy_scoped_resources ||= policy_scope(resource_class)
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
                 .includes(:string_translations, profile_image_attachment: :blob)
                 .order(:name)
    end

    def permitted_attributes
      attrs = [
        :privacy,
        :published_at,
        :contributors_display_visibility,
        *resource_class.localized_attribute_list,
        *resource_class.extra_permitted_attributes
      ]
      attrs.unshift(:community_id) if action_name == 'create'
      attrs
    end

    def community_context
      @community_context ||= resolved_community || helpers.host_community
    end

    def resolved_community
      community_id = params[:community_id].presence
      return if community_id.blank?

      BetterTogether::Community.friendly.find(community_id)
    rescue ActiveRecord::RecordNotFound
      nil
    end

    def scoped_community_ids
      return single_community_ids if params[:community_id].present?

      community_ids = policy_scope(BetterTogether::Community).pluck(:id)
      host = helpers.host_community
      community_ids << host.id if host && !community_ids.include?(host.id) && policy(host).show?
      community_ids
    end

    def single_community_ids
      community_context ? [community_context.id] : []
    end
  end
  # rubocop:enable Metrics/ClassLength
end
