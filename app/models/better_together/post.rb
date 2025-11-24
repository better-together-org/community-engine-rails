# frozen_string_literal: true

module BetterTogether
  # Represents a blog post
  class Post < ApplicationRecord
    include Attachments::Images
    include Authorable
    include BlockFilterable
    include FriendlySlug
    include Categorizable
    include Creatable
    include Identifier
    include Metrics::Viewable
    include Privacy
    include Publishable
    include Searchable
    include TrackedActivity

    attachable_cover_image

    categorizable

    translates :title, type: :string
    alias name title
    translates :content, backend: :action_text

    settings index: default_elasticsearch_index

    slugged :title

    validates :title,
              presence: true

    validates :content,
              presence: true

    # Automatically grant the post creator an authorship record
    after_create :add_creator_as_author

    def to_s
      title
    end

    configure_attachment_cleanup

    # Customize the data sent to Elasticsearch for indexing
    def as_indexed_json(_options = {})
      as_json(
        only: [:id],
        methods: [:title, :name, :slug, *self.class.localized_attribute_list.keep_if do |a|
          a.starts_with?('title' || a.starts_with?('slug') || a.starts_with?('content'))
        end]
      )
    end

    private

    def add_creator_as_author
      return unless respond_to?(:creator_id) && creator_id.present?

      authorships.find_or_create_by(author_id: creator_id)
    end
  end
end
